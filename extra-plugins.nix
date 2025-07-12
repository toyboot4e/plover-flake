{
  inputs,
  plover,
  hid,
  bitarray,
  dulwich,
  odfpy,
  pyparsing,
  setuptools,
  tomli,
  websocket-client,
  hatchling,
  buildPythonPackage,
  fetchPypi,
}:
let
  spylls = buildPythonPackage rec {
    pname = "spylls";
    version = "0.1.7";
    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-cEWJLcvTJNNoX2nFp2AGPnj7g5kTckzhgHfPCgyT8iA=";
    };
  };
  obsws-python = buildPythonPackage rec {
    pname = "obsws_python";
    version = "1.6.1";
    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-n1l4M3xVfp+8pnO1rF3Ww7Vwyi6GCD3/QHLbrZOXp7w=";
    };
    buildInputs = [ hatchling ];
    dependencies = [
      tomli
      websocket-client
    ];
  };
in
{
  plover-machine-hid = buildPythonPackage {
    pname = "plover-machine-hid";
    version = "master";
    src = inputs.plover-machine-hid;
    pyproject = true;
    build-system = [ setuptools ];
    buildInputs = [ plover ];
    dependencies = [
      hid
      bitarray
    ];
    # ModuleNotFoundError: No module named 'PyQt5'
    meta.broken = true;
  };
  plover2cat = buildPythonPackage {
    pname = "plover2cat";
    version = "master";
    src = inputs.plover2cat;
    pyproject = true;
    build-system = [ setuptools ];
    buildInputs = [ plover ];
    dependencies = [
      dulwich
      odfpy
      pyparsing
      spylls
      obsws-python
    ];
  };
}
