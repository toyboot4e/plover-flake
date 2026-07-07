# A Python package set extension (`packageOverrides`) that injects `plover`
# and every plugin from the Plover plugins registry into the package set.
# Apply it with `python3.override { packageOverrides = ..; }` or via
# `pythonPackagesExtensions` in a nixpkgs overlay.
{ inputs, lib }:
final: prev:
let
  # Like `final.callPackage`, but resolves the arguments lazily via
  # `builtins.functionArgs`: the attribute names of this extension's output
  # must not depend on the attribute names of `final`, or evaluating the
  # package set runs into infinite recursion.
  callLazily =
    path: extraArgs:
    let
      fn = import path;
      resolve = name: _: extraArgs.${name} or (final.${name} or final.pkgs.${name});
    in
    fn (builtins.mapAttrs resolve (builtins.functionArgs fn));

  pluginSpecs = builtins.fromJSON (builtins.readFile ./plugins.json);

  makePloverPlugin =
    plugin:
    final.buildPythonPackage {
      pname = plugin.name;
      inherit (plugin) version;
      src = final.fetchPypi {
        inherit (plugin) version sha256;
        pname = lib.lists.head (builtins.split "-[0-9]" plugin.filename);
      };
      buildInputs = [ final.plover ];
      pyproject = true;
      build-system = [ final.setuptools ];
    };

  basicPlugins = builtins.listToAttrs (
    map (plugin: {
      inherit (plugin) name;
      value = makePloverPlugin plugin;
    }) pluginSpecs
  );

  extraPlugins = callLazily ./extra-plugins.nix { inherit inputs; };

  # `overrides.nix` evaluates to an extension (`final: prev: { .. }`) itself
  overrides = callLazily ./overrides.nix { inherit inputs; };

  pluginsBase = extraPlugins // basicPlugins;
  ploverPlugins = pluginsBase // overrides final pluginsBase;
in
ploverPlugins
// {
  plover = final.callPackage ./plover.nix { inherit inputs; };

  # Also group the plugins for enumeration (e.g. `plover-full`):
  inherit ploverPlugins;
}
