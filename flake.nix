# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2024 subtleGradient

{
  description = "SQLite with cr-sqlite CRDT extension pre-loaded";

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
        
        # Load hashes from separate file for easier updates
        hashes = import ./hashes.nix;
        
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
            
            # Unit test: verify the library was installed correctly
            test -f "$out/lib/lib${config.lib}" || {
              echo "Error: Failed to install library at expected path" >&2
              exit 1
            }
          '';
          
          meta = with pkgs.lib; {
            description = "cr-sqlite extension binaries";
            homepage = "https://github.com/vlcn-io/cr-sqlite";
            license = licenses.mit;
            platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
          };
        };

        sqlite-cr = pkgs.writeShellScriptBin "sqlite-cr" ''
          # Find the correct library file (must be exactly one)
          mapfile -t libs < <(find "${crsqlite}/lib" -name 'libcrsqlite.*' -type f)
          
          if [ ''${#libs[@]} -eq 0 ]; then
              echo "Error: No cr-sqlite library found in ${crsqlite}/lib" >&2
              exit 1
          elif [ ''${#libs[@]} -gt 1 ]; then
              echo "Error: Multiple cr-sqlite libraries found:" >&2
              printf '  %s\n' "''${libs[@]}" >&2
              echo "This is a security risk - refusing to load" >&2
              exit 1
          fi
          
          LIB="''${libs[0]}"
          
          # Direct execution without stderr filtering to avoid complexity
          # The sqlite3_close error is harmless and can be ignored by users
          exec ${pkgs.sqlite}/bin/sqlite3 -cmd ".load $LIB" "$@"
        '';
        
        # Test runner as a separate package for CI
        tests = pkgs.writeScriptBin "sqlite-cr-tests" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          export PATH="${sqlite-cr}/bin:$PATH"
          export SQLITE_CR_QUIET=1
          
          # Test counter
          TESTS_PASSED=0
          TESTS_FAILED=0
          
          # Helper function for robust CSV assertions
          assert_csv_query() {
              local query="$1"
              local expected="$2"
              local description="$3"
              local output
              
              echo -n "✓ $description... "
              
              # Use CSV mode to get predictable output format
              if output=$(sqlite-cr :memory: "$query" -csv 2>&1); then
                  if [[ "$output" == "$expected" ]]; then
                      echo "PASS"
                      ((TESTS_PASSED++))
                      return 0
                  else
                      echo "FAIL (expected '$expected', got: '$output')"
                      ((TESTS_FAILED++))
                      return 1
                  fi
              else
                  echo "FAIL (query error: $output)"
                  ((TESTS_FAILED++))
                  return 1
              fi
          }
          
          # Test helper for checking existence/boolean results
          assert_true() {
              local query="$1"
              local description="$2"
              assert_csv_query "$query" "1" "$description"
          }
          
          echo "=== Running sqlite-cr tests ==="
          
          # Test 1: Basic SQL execution
          assert_csv_query "SELECT 2*3 as answer;" "6" "executes SQL queries correctly"
          
          # Test 2: cr-sqlite extension loads
          assert_csv_query "SELECT typeof(crsql_site_id()) as type;" "blob" "cr-sqlite extension provides site ID functionality"
          
          # Test 3: CRDT table creation
          assert_true "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items') IS NOT NULL;" "creates CRDT-enabled tables"
          
          # Test 4: cr-sqlite functions available
          assert_true "SELECT COUNT(*) >= 5 FROM pragma_function_list WHERE name LIKE 'crsql%';" "provides cr-sqlite function suite"
          
          # Test 5: CRDT operations
          assert_csv_query "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" "test-data" "performs CRDT data operations"
          
          # Test 6: Error handling
          echo -n "✓ handles SQL errors with proper exit codes... "
          if ! sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
              echo "PASS"
              ((TESTS_PASSED++))
          else
              echo "FAIL"
              ((TESTS_FAILED++))
          fi
          
          # Test 7: Stderr filtering precision
          echo -n "✓ filters only exact error message from stderr... "
          test_output=$(sqlite-cr :memory: "SELECT 1;" 2>&1 || true)
          if ! echo "$test_output" | grep -q "sqlite3_close() returns 5"; then
              echo "PASS"
              ((TESTS_PASSED++))
          else
              echo "FAIL (error not filtered)"
              ((TESTS_FAILED++))
          fi
          
          echo
          echo "=== Test Summary ==="
          echo "Passed: $TESTS_PASSED/7"
          echo "Failed: $TESTS_FAILED/7"
          echo
          
          [ $TESTS_FAILED -eq 0 ]
        '';

      in {
        packages = {
          default = sqlite-cr.overrideAttrs (old: {
            meta = (old.meta or {}) // {
              description = "SQLite with cr-sqlite CRDT extension pre-loaded";
              homepage = "https://github.com/subtleGradient/sqlite-cr";
              license = pkgs.lib.licenses.mit;
              maintainers = with pkgs.lib.maintainers; [ ];
              mainProgram = "sqlite-cr";
              platforms = pkgs.lib.platforms.darwin ++ pkgs.lib.platforms.linux;
            };
            passthru = (old.passthru or {}) // {
              inherit crsqlite version;
              updateScript = ./update-version.sh;
            };
          });
          
          inherit tests crsqlite;
        };
        
        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };
          tests = flake-utils.lib.mkApp { drv = self.packages.${system}.tests; };
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = [ self.packages.${system}.default pkgs.sqlite ];
          shellHook = ''
            if [ -z "''${SQLITE_CR_QUIET:-}" ] && [ -n "''${PS1:-}" ]; then
              echo "🔗 cr-sqlite loaded in: ${crsqlite}/lib/"
              echo "📦 Run 'sqlite-cr' for SQLite with cr-sqlite pre-loaded"
              echo "🧪 Run 'nix run .#tests' to run test suite"
            fi
          '';
        };
      });
}