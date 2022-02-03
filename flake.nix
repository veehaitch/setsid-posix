{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    let
      cargoTOML = builtins.fromTOML (builtins.readFile ./Cargo.toml);
      name = cargoTOML.package.name;
      version = cargoTOML.package.version;

      lib = nixpkgs.lib;

      rust-toolchainOverlay = final: prev: {
        rust-toolchain = final.rust-bin.fromRustupToolchainFile ./rust-toolchain;
      };

      recursiveMerge = with lib; foldl recursiveUpdate { };
      eachSystem = systems: f: flake-utils.lib.eachSystem systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlay rust-toolchainOverlay self.overlay ];
          };
        in
        f pkgs
      );
      eachDefaultSystem = eachSystem flake-utils.lib.defaultSystems;
    in
    recursiveMerge [
      #
      # COMMON OUTPUTS FOR ALL SYSTEMS
      #
      (eachDefaultSystem (pkgs: rec {
        # `nix build`
        packages.${name} = pkgs.callPackage ./default.nix {
          doCodeStyleCheck = false;
        };
        defaultPackage = packages.${name};

        # `nix check`
        checks."${name}-codestyle" = pkgs.callPackage ./default.nix {
          doCodeStyleCheck = true;
          rustPlatform = with pkgs; makeRustPlatform {
            cargo = rust-toolchain;
            rustc = rust-toolchain;
          };
        };

        checks.nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          mkdir $out #sucess
        '';

        checks.test-util-linux-overlay =
          let
            expectedVersion =
              if pkgs.stdenv.isLinux
              then "setsid from util-linux ${pkgs.util-linux.version}"
              else "${name} ${version}";
            testPkgs = import nixpkgs {
              inherit (pkgs) system;
              overlays = [ self.overlay ];
            };
          in
          with testPkgs; runCommand "test-utillinux-overlay"
            {
              # Uses `utillinux` instead of `util-linux` to make sure the alias works
              buildInputs = [ utillinux tree ];
            } ''
            set -euo pipefail

            VERSION=$(setsid -V)
            if [[ $? != 0 ]]; then
              echo "Executing setsid failed"
            elif [[ $VERSION == "${expectedVersion}" ]]; then
              echo "Found expected version: $VERSION"
              echo "Directory tree:"
              tree ${utillinux}
              mkdir $out
            else
              echo "Didn't find expected setsid from util-linux: $VERSION"
            fi
          '';

        # `nix develop`
        devShell = pkgs.mkShell {
          name = "${name}-dev-shell";

          nativeBuildInputs = with pkgs; [ pkg-config rust-toolchain rust-analyzer ];
          buildInputs = with pkgs; lib.optionals stdenv.isDarwin [
            libiconv
          ];

          RUST_SRC_PATH = "${pkgs.rust-toolchain}/lib/rustlib/src/rust/library";

          shellHook = ''
            export PATH=$PWD/target/debug:$PATH
          '';
        };
      }))
      #
      # SYSTEM-INDEPENDENT OUTPUTS
      #
      {
        overlay = final: prev:
          let
            setsid = self.packages.${prev.system}.${name};
            util-linux-setsid = prev.runCommand "util-linux-setsid"
              {
                propagatedBuildInputs = [ prev.util-linux ];
              } ''
              mkdir "$out"
              ln -s ${prev.util-linux}/* "$out/"

              rm -f     "$out/bin"
              mkdir     "$out/bin"
              chmod 755 "$out/bin"
              ln -s ${prev.util-linux}/bin/* "$out/bin/"

              ln -s "${setsid}/bin/${name}" "$out/bin/setsid"
            '';
            util-linux =
              if prev.stdenv.isLinux
              then prev.util-linux
              else util-linux-setsid;
          in
          {
            "${name}" = setsid;
            inherit util-linux;
          };
      }
    ];
}
