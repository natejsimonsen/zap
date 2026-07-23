APP := Zap
BIN := .build/release/$(APP)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Compile a release binary
	swift build -c release

.PHONY: test
test: ## Run the ZapCore checks
	swift run ZapCoreTests

.PHONY: run
run: ## Run without bundling (Dock icon appears in this mode)
	swift run $(APP)

.PHONY: app
app: ## Build and bundle $(APP).app (ad-hoc signed)
	./build.sh

.PHONY: install
install: app ## Build the bundle and install to /Applications
	rm -rf /Applications/$(APP).app
	cp -R $(APP).app /Applications/
	@echo "Installed. Launch with: open /Applications/$(APP).app"

.PHONY: uninstall
uninstall: ## Remove $(APP).app from /Applications
	rm -rf /Applications/$(APP).app

.PHONY: nix-build
nix-build: ## Build via the Nix flake
	nix --extra-experimental-features "nix-command flakes" build -L

.PHONY: autostart
autostart: ## Start Zap at login (installs a LaunchAgent) and start it now
	@bash contrib/install-login-item.sh

.PHONY: autostart-off
autostart-off: ## Remove the login-item LaunchAgent
	@bash contrib/uninstall-login-item.sh

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf .build $(APP).app Zap.zip result
