{ rustPlatform
, lib
, stdenv
, libiconv
, pkg-config
, doCodeStyleCheck ? true
}:
let
  cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  # Filter out VCS files and files unrelated to the Rust package
  filterRustSource = src: with lib; cleanSourceWith {
    filter = cleanSourceFilter;
    src = cleanSourceWith {
      inherit src;
      filter = name: type:
        let pathWithoutPrefix = removePrefix (toString src) name; in
          ! (
            hasPrefix "/.github" pathWithoutPrefix ||
            pathWithoutPrefix == "/.gitignore" ||
            pathWithoutPrefix == "/LICENSE" ||
            pathWithoutPrefix == "/README.md" ||
            pathWithoutPrefix == "/flake.lock" ||
            pathWithoutPrefix == "/flake.nix"
          );
    };
  };
in
rustPlatform.buildRustPackage rec {
  pname = cargoTOML.package.name;
  version = cargoTOML.package.version;
  src = filterRustSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  inherit doCodeStyleCheck;

  preBuildPhases = lib.optionals doCodeStyleCheck [
    "codeStyleConformanceCheck"
  ];

  codeStyleConformanceCheck = ''
    printf "Checking Rust code formatting"
    cargo fmt -- --check

    printf "Running clippy"
    # clippy - use same checkType as check-phase to avoid double building
    if [ "''${cargoCheckType}" != "debug" ]; then
        cargoCheckProfileFlag="--''${cargoCheckType}"
    fi
    argstr="''${cargoCheckProfileFlag} --workspace --all-features --tests "
    cargo clippy -j $NIX_BUILD_CORES \
       $argstr -- \
       -D clippy::pedantic \
       -D warnings
  '';

  # build dependencies
  nativeBuildInputs = [
    pkg-config
  ];

  # runtime dependencies
  buildInputs = lib.optionals stdenv.isDarwin [
    libiconv
  ];

  doCheck = true;

  postInstall = ''
    # Provide a symlink from `setsid-posix` to `setsid` for compat
    ln -sr "$out/bin/${cargoTOML.package.name}" "$out/bin/setsid"
  '';
}
