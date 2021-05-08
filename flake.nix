{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        name = cargoTOML.package.name;

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlay ];
        };

        rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain;

        naersk-lib = naersk.lib."${system}".override {
          cargo = rust;
          rustc = rust;
        };
      in
      rec {
        # `nix build`
        packages.${name} = naersk-lib.buildPackage {
          pname = name;
          root = ./.;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; lib.optionals stdenv.isDarwin [
            libiconv
          ];

          doCheck = true;
          cargoTestCommands = x: x ++ [
            # clippy
            ''cargo clippy --all --all-features --tests -- -D clippy::pedantic''
            # rustfmt
            ''cargo fmt -- --check''
          ];
        };
        defaultPackage = packages.${name};

        # `nix run`
        apps.${name} = flake-utils.lib.mkApp {
          drv = packages.${name};
        };
        defaultApp = apps.${name};

        # `nix develop`
        devShell = pkgs.mkShell {
          name = "${name}-dev-shell";

          nativeBuildInputs = [ rust pkgs.pkg-config ];
          buildInputs = with pkgs; lib.optionals stdenv.isDarwin [
            libiconv
          ];

          RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";

          shellHook = ''
            export PATH=$PWD/target/debug:$PATH
          '';
        };
      });
}
