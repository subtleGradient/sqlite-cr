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
            mapfile -t found < <(find . -name "${config.lib}" -type f)
            if [ "''${#found[@]}" -eq 0 ]; then
              echo "Error: ${config.lib} not found in archive" >&2
              exit 1
            elif [ "''${#found[@]}" -gt 1 ]; then
              echo "Error: multiple ${config.lib} files found:" >&2
              printf '  %s\n' "''${found[@]}" >&2
              exit 1
            fi
            cp "''${found[0]}" "$out/lib/lib${config.lib}"

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
          set -euo pipefail
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

          # Surgical stderr filter for sqlite3_close() returns 5 error
          if [ -n "''${SQLITE_CR_SHOW_CLOSE5:-}" ]; then
              # User wants to see the close5 error
              exec ${pkgs.sqlite}/bin/sqlite3 -cmd ".load \"$LIB\"" "$@"
          else
              # Filter out the specific error line when exit code is 0
              tmpfile="$(${pkgs.coreutils}/bin/mktemp)"
              ${pkgs.sqlite}/bin/sqlite3 -cmd ".load \"$LIB\"" "$@" 2>"$tmpfile"
              exit_code=$?

              if [ $exit_code -eq 0 ]; then
                  # Success: filter out the exact error line
                  ${pkgs.gnused}/bin/sed '/^Error: sqlite3_close() returns 5: unable to close due to unfinalized statements or unfinished backups$/d' "$tmpfile" >&2
              else
                  # Error: show all stderr as-is
                  cat "$tmpfile" >&2
              fi

              rm -f "$tmpfile"
              exit $exit_code
          fi
        '';

        # Test runner as a separate package for CI
        tests = pkgs.writeScriptBin "sqlite-cr-tests" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          export PATH="${sqlite-cr}/bin:$PATH"

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
              if output=$(sqlite-cr -csv :memory: "$query" 2>&1); then
                  if [[ "$output" == "$expected" ]]; then
                      echo "PASS"
                      ((TESTS_PASSED+=1))
                      return 0
                  else
                      echo "FAIL (expected '$expected', got: '$output')"
                      ((TESTS_FAILED+=1))
                      return 1
                  fi
              else
                  echo "FAIL (query error)"
                  >&2 printf '%s\n' "$output"
                  ((TESTS_FAILED+=1))
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
          assert_csv_query "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" "OK
test-data" "performs CRDT data operations"

          # Test 6: Error handling
          echo -n "✓ handles SQL errors with proper exit codes... "
          if ! sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
              echo "PASS"
              ((TESTS_PASSED+=1))
          else
              echo "FAIL"
              ((TESTS_FAILED+=1))
          fi

          # Test 7: Stderr filtering (close5 error suppressed on success)
          echo -n "✓ suppresses sqlite3_close error on successful execution... "
          stderr_output=$({ sqlite-cr :memory: "SELECT 1;" 1>/dev/null; } 2>&1)
          if [[ ! "$stderr_output" =~ "sqlite3_close() returns 5" ]]; then
              echo "PASS"
              ((TESTS_PASSED+=1))
          else
              echo "FAIL (close5 error not filtered: $stderr_output)"
              ((TESTS_FAILED+=1))
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

        checks = {
          tests = self.packages.${system}.tests;
        };

        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };
          tests = flake-utils.lib.mkApp { drv = self.packages.${system}.tests; };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            self.packages.${system}.default
            pkgs.sqlite
            pkgs.jq
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.fswatch ];
          shellHook = ''
            if [ -n "''${PS1:-}" ]; then
              echo "🔗 cr-sqlite loaded in: ${crsqlite}/lib/"
              echo "📦 Run 'sqlite-cr' for SQLite with cr-sqlite pre-loaded"
              echo "🧪 Run 'nix run .#tests' to run test suite"
            fi
          '';
        };
      });
}
