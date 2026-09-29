{
  pkgs,
  stdenv,
  autoPatchelfHook,
  zlib,
  ncurses5,
  version ? "10.3.1_v6",
}:

let 
  versionmap = {
    "10.3.1_v6" = {
      simple = "10.3.1";
      build = "4523";
    };
    "10.3.1_v7" = {
      simple = "10.3.1";
      build = "4602";
    };
  };
  simpleVersion = versionmap.${version}.simple;
  buildVersion = versionmap.${version}.build;
in

stdenv.mkDerivation rec {
  pname = "asdk";
  inherit version;
  src = builtins.fetchTarball "https://github.com/Ameba-AIoT/ameba-toolchain/releases/download/${version}/${pname}-${simpleVersion}-linux-newlib-build-${buildVersion}-x86_64_with_small_reent.tar.bz2";

  dontUnpack = true;
  dontConfigure = true;
  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib
    ncurses5
    zlib
  ];

  installPhase = ''
    mkdir -p "$out/${pname}-${simpleVersion}-${buildVersion}"
    cp -r "$src"/* "$out/${pname}-${simpleVersion}-${buildVersion}/"
  '';

  newlib_path = "${pname}-${simpleVersion}-${buildVersion}/linux/newlib";
}
