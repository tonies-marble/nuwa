let
  nixpkgs_rev = "nixos-25.11";
  nixpkgs_src = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/${nixpkgs_rev}.tar.gz";
in

{
  pkgs ? import nixpkgs_src {config.permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.1"
    "mbedtls-2.28.10"
  ];}
}:

let
  pyproject-nix-ref = "69f57f27e52a87c54e28138a75ec741cd46663c9";
  zephyr-nix-ref = "6966fb1cbf2fdb494bea3062c5e8e7d44dd8ac9c";
  zephyr-src-ref = "v4.4.0";
  asdk-version = "10.3.1_v7";
in

let
  zephyr-nix = ((import (builtins.fetchTarball "https://github.com/nix-community/zephyr-nix/archive/${zephyr-nix-ref}.tar.gz")) {
    inherit (pkgs) lib newScope openocd autoreconfHook fetchFromGitHub gcc_multi python312;

    zephyr-src = builtins.fetchTarball "https://github.com/zephyrproject-rtos/zephyr/archive/${zephyr-src-ref}.tar.gz";

    pyproject-nix = (import (builtins.fetchTarball "https://github.com/pyproject-nix/pyproject.nix/archive/${pyproject-nix-ref}.tar.gz")) {
      inherit (pkgs) lib;
    };
  });

  sdk = zephyr-nix.sdk.override {
    targets = [
      "arm-zephyr-eabi"
    ];
  };

  asdk = pkgs.callPackage ./asdk.nix { version = asdk-version;};
in
pkgs.mkShell {
  packages = with pkgs; [
    ccache
    cmake
    ninja
    sdk
    zephyr-nix.hosttools
    (zephyr-nix.pythonEnv.override {
      extraPackages = ps: with ps; [
        capstone
        click
        colorama
        cryptography
        ecdsa
        fastmcp
        filelock
        json5
        packaging
        prompt-toolkit
        pycryptodome
        pydes
        pyelftools
        pyfatfs
        pyserial
        python-mbedtls
        requests

        # pqcrypto is a PyO3/maturin Rust extension. Building the sdist from
        # source needs the maturin PEP 517 backend importable under
        # --no-isolation plus a full Rust toolchain, which is fragile here.
        # Upstream publishes prebuilt cp39-abi3 manylinux wheels, so we grab
        # the x86_64 wheel directly instead. autoPatchelfHook rewrites the
        # bundled .so's RPATH so the Nix loader resolves libc/libgcc_s
        # (a dlopen'd extension does not go through nix-ld).
        (buildPythonPackage rec {
          pname = "pqcrypto";
          version = "1.0.0";
          format = "wheel";
          src = fetchPypi {
            inherit pname version format;
            dist = "cp39";
            python = "cp39";
            abi = "abi3";
            platform = "manylinux_2_34_x86_64";
            sha256 = "7068532dbc1225a9d668d59940bd96dc13f40175a757b2e31c69aa697781f4d0";
          };
          nativeBuildInputs = [ autoPatchelfHook ];
          buildInputs = [ stdenv.cc.cc.lib ];
        })

        (buildPythonPackage rec {
          pname = "littlefs_python";
          version = "0.19.0";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-TOjG7usnA6uvjLYPLatiSxevQrE989vGxC1BQrrXmlk=";
          };
          pyproject = true;
          build-system = [
            cython
            setuptools
            setuptools-scm
          ];
        })

        (buildPythonPackage rec {
          pname = "sslcrypto";
          version = "5.3";
          src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-g1q61RbPGveeZR8jPwDFEyEH5RWATIzCmNaHhepzPVg=";
          };
          pyproject = true;
          build-system = [ setuptools ];
          propagatedBuildInputs = [
            pyaes
            base58
          ];
          pythonRelaxDeps = [ "base58" ];
        })
      ];
    })
  ];

  # ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
  # ZEPHYR_SDK_INSTALL_DIR = "${sdk}";
  ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
  GNUARMEMB_TOOLCHAIN_PATH = "${asdk}/${asdk.newlib_path}";
  RTK_TOOLCHAIN_DIR = "${asdk}";
}
