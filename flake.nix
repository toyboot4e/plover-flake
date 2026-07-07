{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    plover = {
      url = "github:openstenoproject/plover";
      flake = false;
    };
    plover_plugins_registry = {
      url = "github:openstenoproject/plover_plugins_registry";
      flake = false;
    };
    rtf-tokenize = {
      url = "github:openstenoproject/rtf_tokenize";
      flake = false;
    };
    plover-stroke = {
      url = "github:openstenoproject/plover_stroke";
      flake = false;
    };
    plover2cat = {
      url = "github:greenwyrt/plover2CAT";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = lib.systems.flakeExposed;

      # [HACK]
      # Override cctools `ld` with LLVM's `lld` to avoid Qt 6.11 modules with naive Darwin plugins such as WebKit.
      # We patch `python.pkgs.qt6` rather than `pkgs.qt6`, because `overrideScope` on the latter drops its `.override`,
      # which `python-packages.nix` calls.
      qtLldDarwinOverlay =
        final: prev:
        lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (
              pyFinal: pyPrev:
              let
                withLld =
                  drv:
                  drv.overrideAttrs (old: {
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.llvmPackages.lld ];
                    env = (old.env or { }) // {
                      NIX_CFLAGS_LINK = "-fuse-ld=lld";
                    };
                  });
              in
              {
                pyside6 = withLld pyPrev.pyside6;
                qt6 = pyPrev.qt6.overrideScope (
                  _qtFinal: qtPrev:
                  lib.genAttrs [
                    "qtwebview"
                    "qtspeech"
                    "qtconnectivity"
                    "qtpositioning"
                    "qtlocation"
                  ] (name: withLld qtPrev.${name})
                );
              }
            )
          ];
        };

      pkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ qtLldDarwinOverlay ];
        }
      );
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
      treefmtEval = forEachSystem (
        pkgs: inputs.treefmt-nix.lib.evalModule pkgs { programs.nixfmt.enable = true; }
      );

      # A Python package set extension injecting `plover` and all the plugins
      pythonOverlay = import ./python-overlay.nix { inherit inputs lib; };
      ploverPythonFor =
        pkgs:
        let
          python = pkgs.python3.override {
            self = python;
            packageOverrides = pythonOverlay;
          };
        in
        python;
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            statix
            nixd
          ];
        };
      });

      formatter = forEachSystem (
        pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper
      );

      checks = forEachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });

      # The Python package set extension (`final: prev: { .. }`) that adds
      # `plover` and all the plugins. Compose it with your own overrides via
      # `python3.override { packageOverrides = ..; }`.
      pythonPackagesOverlay = pythonOverlay;

      ploverPlugins = forEachSystem (pkgs: (ploverPythonFor pkgs).pkgs.ploverPlugins);

      packages = forEachSystem (
        pkgs:
        let
          python = ploverPythonFor pkgs;
          withPlugins =
            f: # f is a function such as (ps: with ps; [ plugin names ])
            pkgs.callPackage ./with-plugins.nix { inherit python; } f;
          availablePloverPlugins = builtins.filter (x: x ? meta && !x.meta.broken) (
            builtins.attrValues python.pkgs.ploverPlugins
          );
        in
        rec {
          default = plover;

          plover = (python.pkgs.toPythonApplication python.pkgs.plover) // {
            inherit withPlugins;
          };

          plover-full = (withPlugins (ps: availablePloverPlugins)) // {
            withPlugins = f: withPlugins (ps: availablePloverPlugins ++ f ps);
          };

          update = pkgs.callPackage ./update.nix { inherit inputs; };
        }
      );

      homeManagerModules = rec {
        plover = import ./hm-module.nix self;
      };
    };
}
