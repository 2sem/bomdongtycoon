TUIST := mise x -- tuist
WORKSPACE := BomDongTycoon.xcworkspace
SCHEME := BomDongTycoon
# Google's packages declare iOS 12 and Xcode 27 rejects simulator targets below 15 ("deployment
# target is set to 12.0"). Tuist rewrites the package projects on every generate, so every
# generate target ends with this patch.
PATCH := tools/fix-package-deployment-targets.sh

.PHONY: setup init install patch generate generate-open generate-no-cache generate-clean build test cache clean install-clean graph archive archive-clean
.PHONY: ins gen ca s i c ic b t g gc gn o gr ar
.PHONY: ig go bt rebuild

# First-time bootstrap: tools, packages, workspace (add `git secret reveal` here if the repo uses git-secret)
setup: init
	$(MAKE) install generate

# Install mise (if missing, needs Homebrew) and the tuist version pinned in .mise.toml
init:
	@command -v mise >/dev/null 2>&1 || brew install mise
	mise install

# Resolve Swift package dependencies (tuist < 4: use `fetch`)
install:
	$(TUIST) install

# Lift the generated package projects to a deployment target Xcode accepts
patch:
	$(PATCH)

# Generate the Xcode workspace
generate:
	$(TUIST) generate --no-open
	$(PATCH)

# Generate the Xcode workspace and open it
generate-open:
	$(TUIST) generate --no-open
	$(PATCH)
	open $(WORKSPACE)

# Generate building every package from source (cache profile none)
generate-no-cache:
	$(TUIST) generate --no-open --cache-profile none
	$(PATCH)

# Wipe fetched packages and cached binaries, re-fetch, then generate
generate-clean: clean install generate

# Build the app
build:
	$(TUIST) build

# Run tests
test:
	$(TUIST) test

# Cache binaries
cache:
	$(TUIST) cache

# Wipe fetched packages and cached binaries
clean:
	$(TUIST) clean dependencies binaries

# Wipe, then re-fetch packages
install-clean: clean install

# Generate the dependency graph without external dependencies
graph:
	$(TUIST) graph --skip-external-dependencies

# Archive the current generation into Xcode's Organizer
archive:
	xcodebuild archive \
		-workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-allowProvisioningUpdates

# Archive a release. Never archive off a cached generation: `tuist cache` stores
# xcframeworks with no dSYMs, so prebuilt frameworks get linked and the dSYMs
# Crashlytics needs are never produced.
archive-clean: clean install generate-no-cache archive

# --- Short aliases ---
ins: install
gen: generate
ca: cache
s: setup
i: install
c: clean
ic: install-clean
b: build
t: test
g: generate
gc: generate-clean
gn: generate-no-cache
o: generate-open
gr: graph
ar: archive-clean

# --- Combos (run serially; do not use make -j) ---

# Resolve packages, then generate the workspace
ig: install generate

# Resolve packages, generate the workspace, then build
go: install generate build

# Build then run tests
bt: build test

# Full reset: wipe, re-fetch, regenerate, build
rebuild: clean install generate build
