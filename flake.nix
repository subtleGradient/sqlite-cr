{
  description = "SQLite + crSQLite dev env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Download pre-built cr-sqlite binaries for all platforms
        platformConfig = {
          "aarch64-darwin" = {
            url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-darwin-aarch64.zip";
            hash = "sha256-3SX8QwdI+WBUSgjdZq9xnPhQWtJrBXFamzrcMiWhOWM=";
            lib = "crsqlite.dylib";
          };
          "x86_64-darwin" = {
            url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-darwin-x86_64.zip";
            hash = "sha256-1ps0vlpf3j6914qjpymm1j7fw10s4sz3q23w064mipc22rgdsckr";
            lib = "crsqlite.dylib";
          };
          "x86_64-linux" = {
            url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-linux-x86_64.zip";
            hash = "sha256-0q21a13mi0hrmg5d928vbnqvhrixd3qfs6cd1bbya17m6f1ic3d0";
            lib = "crsqlite.so";
          };
          "aarch64-linux" = {
            url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-linux-aarch64.zip";
            hash = "sha256-1cspr6rv1r86jym8lplpajzhj623n9dzvhszfccblhmrxzm9csdr";
            lib = "crsqlite.so";
          };
        };

        config = platformConfig.${system} or (throw "Unsupported platform: ${system}");

        crsqlite = pkgs.stdenv.mkDerivation rec {
          pname = "crsqlite";
          version = "0.16.3";

          src = pkgs.fetchzip {
            url = config.url;
            hash = config.hash;
            stripRoot = false;
          };

          installPhase = ''
            mkdir -p $out/lib
            # Handle both root and subdirectory extraction
            if [ -f ${config.lib} ]; then
              cp ${config.lib} $out/lib/lib${config.lib}
            else
              find . -name ${config.lib} -exec cp {} $out/lib/lib${config.lib} \;
            fi
          '';
        };

        sqlite-cr = pkgs.writeShellScriptBin "sqlite-cr" ''
          # Find the correct library file
          LIB=$(find "${crsqlite}/lib" -name 'libcrsqlite.*' | head -n1)
          
          # Stream output directly with stderr filtering
          exec ${pkgs.sqlite}/bin/sqlite3 -cmd ".load $LIB" "$@" \
            2> >(grep -v "sqlite3_close() returns 5" >&2)
        '';

      in {
        packages.default = sqlite-cr // {
          meta = { mainProgram = "sqlite-cr"; };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [ sqlite-cr pkgs.sqlite ];
          shellHook = ''
            if [ -z "''${SQLITE_CR_QUIET:-}" ]; then
              echo "🔗 crsqlite dylib is at: ${crsqlite}/lib/libcrsqlite.dylib"
              echo "📦 Run 'sqlite-cr' for SQLite with cr-sqlite pre-loaded"
              echo "📦 Run 'sqlite3' and then '.load ${crsqlite}/lib/libcrsqlite.dylib' for manual loading"
            fi
          '';
        };
      });
}
