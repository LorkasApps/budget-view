.DEFAULT_GOAL := help
.PHONY: help get upgrade outdated analyze format format-check test test-name coverage \
        run run-release gen gen-watch icons splash clean doctor build-apk build-appbundle \
        install-apk check pre-commit devices

## ---------------------------------------------------------------------------
## BudgetView — developer command reference
## Run `make <target>`. Flutter cannot run inside the agent sandbox, so these
## are the canonical commands to invoke locally.
## ---------------------------------------------------------------------------

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- Dependencies ----------------------------------------------------------
get: ## Resolve dependencies (flutter pub get)
	flutter pub get

upgrade: ## Upgrade dependencies to latest allowed
	flutter pub upgrade

outdated: ## Show outdated dependencies
	flutter pub outdated

# --- Static analysis / formatting ------------------------------------------
analyze: ## Run the analyzer (flutter_lints)
	flutter analyze

format: ## Format all Dart code
	dart format lib test

format-check: ## Verify formatting without writing (CI-friendly)
	dart format --set-exit-if-changed lib test

# --- Tests -----------------------------------------------------------------
test: ## Run all tests
	flutter test

test-name: ## Run tests matching NAME=... (make test-name NAME="dedupe")
	flutter test --plain-name "$(NAME)"

coverage: ## Run tests with coverage → coverage/lcov.info
	flutter test --coverage

# --- Code generation (Isar / build_runner, used from ticket 002 onwards) ---
gen: ## One-shot code generation
	dart run build_runner build
gen-watch: ## Watch + regenerate on change
	dart run build_runner watch

# --- Branding assets (launcher icon + launch screen) -----------------------
# Both read assets/icon/*.png. Output is generated into android/ and committed.
icons: ## Regenerate the Android launcher icons from assets/icon
	dart run flutter_launcher_icons

splash: ## Regenerate the Android launch screen from assets/icon
	dart run flutter_native_splash:create

# --- Run / build -----------------------------------------------------------
devices: ## List connected devices / emulators
	flutter devices

run: ## Run debug build on the default device
	flutter run

run-release: ## Run release build on the default device
	flutter run --release

build-apk: ## Build release APK
	flutter build apk --release

build-appbundle: ## Build release App Bundle (Play Store)
	flutter build appbundle --release

install-apk: ## Install the built release APK on the connected device
	flutter install

# --- Housekeeping ----------------------------------------------------------
clean: ## Clean build artifacts
	flutter clean

doctor: ## Flutter environment diagnostics
	flutter doctor -v

# --- Aggregates ------------------------------------------------------------
check: analyze test ## Analyze + test (fast quality gate)

pre-commit: format-check analyze test ## Full pre-commit gate
