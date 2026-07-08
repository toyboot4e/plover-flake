# A Python package set extension (`packageOverrides`) that injects `plover`
# and every plugin from the Plover plugins registry into the package set.
# Apply it with `python3.override { packageOverrides = ..; }` or via
# `pythonPackagesExtensions` in a nixpkgs overlay.
#
# NOTE: The attribute names of this extension's output must not depend on the
# attribute names of `final` (e.g. via `final.callPackage` in name position),
# or evaluating the package set runs into infinite recursion. This is why
# `extra-plugins.nix` and `overrides.nix` are imported and applied directly.
{ inputs, lib }:
final: prev:
let
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

  extraPlugins = import ./extra-plugins.nix { inherit inputs; } final prev;

  overrides = import ./overrides.nix { inherit inputs; };

  pluginsBase = extraPlugins // basicPlugins;
  ploverPlugins = pluginsBase // overrides final pluginsBase;
in
ploverPlugins
// {
  plover = final.callPackage ./plover.nix { inherit inputs; };

  # Also group the plugins for enumeration (e.g. `plover-full`):
  inherit ploverPlugins;
}
