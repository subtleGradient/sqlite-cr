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
        
        # Download pre-built binary for macOS
        crsqlite = pkgs.stdenv.mkDerivation rec {
          pname = "crsqlite";
          version = "0.16.3";
          
          src = if system == "aarch64-darwin" then
            pkgs.fetchzip {
              url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v${version}/crsqlite-darwin-aarch64.zip";
              hash = "sha256-3SX8QwdI+WBUSgjdZq9xnPhQWtJrBXFamzrcMiWhOWM=";
              stripRoot = false;
            }
          else if system == "x86_64-darwin" then
            pkgs.fetchzip {
              url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v${version}/crsqlite-darwin-x86_64.zip";
              hash = "sha256-3SX8QwdI+WBUSgjdZq9xnPhQWtJrBXFamzrcMiWhOWM=";
              stripRoot = false;
            }
          else
            pkgs.fetchzip {
              url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v${version}/crsqlite-linux-x86_64.zip";
              hash = "sha256-3SX8QwdI+WBUSgjdZq9xnPhQWtJrBXFamzrcMiWhOWM=";
              stripRoot = false;
            };
          
          installPhase = ''
            mkdir -p $out/lib
            if [[ "$system" == *"darwin"* ]]; then
              cp crsqlite.dylib $out/lib/libcrsqlite.dylib
            else
              cp crsqlite.so $out/lib/libcrsqlite.so
            fi
            chmod +x $out/lib/*
          '';
        };
        
        sqlite-cr = pkgs.writeShellScriptBin "sqlite-cr" ''
          LIB="${crsqlite}/lib/libcrsqlite.dylib"
          [ ! -f "$LIB" ] && LIB="${crsqlite}/lib/libcrsqlite.so"
          
          # Run sqlite3 and capture exit code
          set +e
          output=$(${pkgs.sqlite}/bin/sqlite3 -cmd ".load $LIB" "$@" 2>&1)
          exit_code=$?
          set -e
          
          # Filter output and preserve exit code
          echo "$output" | grep -v "sqlite3_close() returns 5" || true
          exit $exit_code
        '';
        
      in {
        packages.default = sqlite-cr;
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