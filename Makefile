# sqlite-cr Makefile
# Idiomatic make targets for common development tasks

# Default target
.DEFAULT_GOAL := help

# Variables
NIX_RUN := nix run .# --
NIX_BUILD := nix build
PLATFORMS := x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin
CURRENT_VERSION := $(shell grep 'version = ' flake.nix | cut -d'"' -f2)

# Phony targets (not files)
.PHONY: help build test check run shell clean update-version release install dev ci all

## help: Show this help message
help:
	@echo "sqlite-cr development tasks:"
	@echo
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  make /' | column -t -s ':'

## build: Build sqlite-cr for current platform
build:
	$(NIX_BUILD)
	@echo "✅ Built: ./result/bin/sqlite-cr"

## test: Run the test suite
test:
	@echo "Running tests..."
	@./sqlite-cr.spec.sh

## check: Run flake checks (lint, format, etc)
check:
	nix flake check

## run: Run sqlite-cr with example query
run: build
	./result/bin/sqlite-cr :memory: "SELECT 'Hello from make!';"

## shell: Enter development shell
shell:
	nix develop

## dev: Enter dev shell and run tests
dev:
	nix develop -c bash -c "echo '🚀 Development shell ready!' && exec $$SHELL"

## clean: Remove build artifacts
clean:
	rm -rf result result-*
	@echo "✅ Cleaned build artifacts"

## install: Install to user profile
install:
	nix profile install .
	@echo "✅ Installed sqlite-cr to user profile"

## ci: Simulate CI locally (check all platforms)
ci:
	@echo "🔍 Checking for placeholder hashes..."
	@if grep -q 'fakeSha256' flake.nix; then \
		echo "❌ Error: Found fakeSha256 in flake.nix"; \
		exit 1; \
	fi
	@echo "✅ No placeholder hashes found"
	@echo
	@echo "🏗️  Building all platforms..."
	@for platform in $(PLATFORMS); do \
		echo "  Building $$platform..."; \
		$(NIX_BUILD) .#packages.$$platform.default --no-link || exit 1; \
	done
	@echo "✅ All platforms build successfully"
	@echo
	@$(MAKE) test

## all: Build, check, and test
all: build check test
	@echo "✅ All tasks completed successfully"

# Version management targets

## version: Show current version
version:
	@echo "Current version: $(CURRENT_VERSION)"

## update-version: Update cr-sqlite version (usage: make update-version VERSION=0.17.0)
update-version:
ifndef VERSION
	@echo "❌ Error: VERSION not specified"
	@echo "Usage: make update-version VERSION=0.17.0"
	@exit 1
endif
	@echo "📦 Updating to version $(VERSION)..."
	@./update-version.sh $(VERSION)

# Release targets

## release-patch: Create a patch release (x.y.Z+1)
release-patch:
	@echo "Creating patch release..."
	@VERSION=$$(echo $(CURRENT_VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}') && \
	$(MAKE) update-version VERSION=$$VERSION && \
	git add -A && \
	git commit -m "Release v$$VERSION" && \
	git tag -a "v$$VERSION" -m "Release version $$VERSION" && \
	echo "✅ Created release v$$VERSION" && \
	echo "📤 Run 'git push && git push --tags' to publish"

## release-minor: Create a minor release (x.Y+1.0)
release-minor:
	@echo "Creating minor release..."
	@VERSION=$$(echo $(CURRENT_VERSION) | awk -F. '{print $$1"."$$2+1".0"}') && \
	$(MAKE) update-version VERSION=$$VERSION && \
	git add -A && \
	git commit -m "Release v$$VERSION" && \
	git tag -a "v$$VERSION" -m "Release version $$VERSION" && \
	echo "✅ Created release v$$VERSION" && \
	echo "📤 Run 'git push && git push --tags' to publish"

## release-major: Create a major release (X+1.0.0)
release-major:
	@echo "Creating major release..."
	@VERSION=$$(echo $(CURRENT_VERSION) | awk -F. '{print $$1+1".0.0"}') && \
	$(MAKE) update-version VERSION=$$VERSION && \
	git add -A && \
	git commit -m "Release v$$VERSION" && \
	git tag -a "v$$VERSION" -m "Release version $$VERSION" && \
	echo "✅ Created release v$$VERSION" && \
	echo "📤 Run 'git push && git push --tags' to publish"

# Quick test targets

## quick: Quick smoke test
quick:
	@$(NIX_RUN) :memory: "SELECT crsql_site_id() IS NOT NULL as ok;" | grep -q "1" && \
	echo "✅ Quick test passed" || \
	(echo "❌ Quick test failed" && exit 1)

## bench: Simple benchmark
bench: build
	@echo "Running simple benchmark..."
	@time ./result/bin/sqlite-cr :memory: "
		CREATE TABLE test(id INTEGER PRIMARY KEY, data TEXT);
		SELECT crsql_as_crr('test');
		WITH RECURSIVE gen(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM gen WHERE i<1000)
		INSERT INTO test SELECT i, 'data-' || i FROM gen;
		SELECT COUNT(*) as records FROM test;
	"

# Docker targets (if someone wants to containerize)

## docker: Build Docker image with Nix
docker:
	@echo "Building Docker image..."
	@nix build .#dockerImage
	@echo "✅ Docker image built: ./result"
	@echo "📦 Load with: docker load < ./result"

# Development helpers

## watch: Watch for changes and run tests
watch:
	@echo "Watching for changes..."
	@while true; do \
		inotifywait -q -e modify,create,delete -r . --exclude result; \
		clear; \
		$(MAKE) test; \
	done

## format: Format Nix files
format:
	@echo "Formatting Nix files..."
	@nixpkgs-fmt *.nix
	@echo "✅ Formatting complete"

# Maintenance targets

## deps: Show flake dependencies
deps:
	@echo "📦 Flake inputs:"
	@nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.key != "root") | "  - \(.key): \(.value.locked.rev[0:8])"'

## update: Update all flake inputs
update:
	nix flake update
	@echo "✅ Updated flake.lock"
	@echo "💡 Run 'make test' to verify updates work"

## info: Show project information
info:
	@echo "📊 Project: sqlite-cr"
	@echo "📌 Version: $(CURRENT_VERSION)"
	@echo "🏗️  Platform: $$(nix eval --raw .#packages.$$(nix eval --impure --expr builtins.currentSystem).default.system)"
	@echo "📦 cr-sqlite: v$(CURRENT_VERSION)"
	@echo "🔧 Nix version: $$(nix --version)"

# Git helpers

## status: Show git and build status
status:
	@echo "📊 Git status:"
	@git status --short
	@echo
	@echo "🏗️  Build status:"
	@ls -la result 2>/dev/null || echo "  No build artifacts"
	@echo
	@$(MAKE) version