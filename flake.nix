{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.05";
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
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, naersk }:
    let
      cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      name = cargoTOML.package.name;
      version = cargoTOML.package.version;
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
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
              ''cargo clippy --all --all-features --tests -- -D clippy::pedantic -D warnings''
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

          # `nix check`
          checks.test-utillinux-overlay =
            let
              expectedVersion =
                if pkgs.stdenv.isLinux
                then "setsid from util-linux ${pkgs.utillinux.version}"
                else "setsid ${version}";
              testPkgs = import nixpkgs {
                inherit system;
                overlays = [ self.overlay ];
              };
            in
            with testPkgs; runCommand "test-utillinux-overlay"
              {
                buildInputs = [ utillinux tree ];
              } ''
              VERSION=$(setsid -V)
              if [[ $? != 0 ]]; then
                echo "Executing setsid failed"
              elif [[ $VERSION == "${expectedVersion}" ]]; then
                echo "Found expected version: $VERSION"
                echo "Directory tree:"
                tree ${utillinux}
                mkdir $out
              else
                echo "Didn't find expected setsid from utillinux: $VERSION"
              fi
            '';

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
        }) // {
      overlay = final: prev:
        let
          setsid = self.packages.${prev.system}.${name};
          utillinux-setsid = prev.runCommandNoCC "utillinux-setsid"
            {
              propagatedBuildInputs = [ prev.utillinux ];
            } ''
            mkdir "$out"
            ln -s ${prev.utillinux}/* "$out/"

            rm -f     "$out/bin"
            mkdir     "$out/bin"
            chmod 755 "$out/bin"
            ln -s ${prev.utillinux}/bin/* "$out/bin/"

            ln -s "${setsid}/bin/${name}" "$out/bin/setsid"
          '';
          utillinux =
            if prev.stdenv.isLinux
            then prev.utillinux
            else utillinux-setsid;
        in
        {
          "${name}" = setsid;
          inherit utillinux;
        };
    };
}
