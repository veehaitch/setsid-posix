{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    naersk.url = "github:nmattia/naersk";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, naersk, flake-compat }:
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

          shellHook = ''
            export PATH=$PWD/target/debug:$PATH
          '';
        };
      });
}
