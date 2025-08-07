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

        version = "0.16.3";
        
        # Constants to avoid duplication
        errorToFilter = "sqlite3_close() returns 5";
        
        # Single source of truth for hashes
        hashes = {
          "aarch64-darwin" = "sha256-3SX8QwdI+WBUSgjdZq9xnPhQWtJrBXFamzrcMiWhOWM=";
          "x86_64-darwin" = "sha256-1ps0vlpf3j6914qjpymm1j7fw10s4sz3q23w064mipc22rgdsckr";
          "x86_64-linux" = "sha256-0q21a13mi0hrmg5d928vbnqvhrixd3qfs6cd1bbya17m6f1ic3d0";
          "aarch64-linux" = "sha256-1cspr6rv1r86jym8lplpajzhj623n9dzvhszfccblhmrxzm9csdr";
        };

        # Platform-specific configuration
        libName = if pkgs.stdenv.isDarwin then "crsqlite.dylib" else "crsqlite.so";
        platform = if pkgs.stdenv.isDarwin then "darwin" else "linux";
        arch = if system == "aarch64-darwin" || system == "aarch64-linux" then "aarch64" else "x86_64";
        
        config = {
          url = "https://github.com/vlcn-io/cr-sqlite/releases/download/v${version}/crsqlite-${platform}-${arch}.zip";
          hash = hashes.${system} or (throw "Unsupported platform: ${system}");
          lib = libName;
        };

        crsqlite = pkgs.stdenv.mkDerivation rec {
          pname = "crsqlite";
          inherit version;

          src = pkgs.fetchzip {
            url = config.url;
            hash = config.hash;
            stripRoot = false;
          };

          installPhase = ''
            mkdir -p $out/lib
            # Find exactly one library file and install it
            libFile=$(find . -name ${config.lib} -type f | head -n1)
            if [ -z "$libFile" ]; then
              echo "Error: ${config.lib} not found in archive" >&2
              exit 1
            fi
            cp "$libFile" $out/lib/lib${config.lib}
          '';
        };

        sqlite-cr = pkgs.writeShellScriptBin "sqlite-cr" ''
          # Find the correct library file
          LIB=$(find "${crsqlite}/lib" -name 'libcrsqlite.*' | head -n1)
          
          # Stream output directly with stderr filtering
          exec ${pkgs.sqlite}/bin/sqlite3 -cmd ".load $LIB" "$@" \
            2> >(grep -v "${errorToFilter}" >&2)
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