# Written for BASH
SHELL := bash

# Set default shell flags
.SHELLFLAGS := -eu -o pipefail -c

# Delete target file if make rule fails
.DELETE_ON_ERROR:

# Warn about undefined vars early
MAKEFLAGS += --warn-undefined-variables

# Turn off built-in implicit rules
MAKEFLAGS += --no-builtin-rules

# Running `make` will trigger `make help`
.DEFAULT_GOAL := help

# Project settings
PROJECT_NAME := VoiceToText
SCHEME := VoiceToText
CONFIGURATION := Debug
TEST_DESTINATION := platform=macOS

# Get the actual app bundle path from xcodebuild
APP_BUNDLE := $(shell xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) -configuration $(CONFIGURATION) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/$(PROJECT_NAME).app

help: ## Show available targets
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+.*## .*' $(MAKEFILE_LIST) | awk 'BEGIN {FS = "## "}; {printf "  %-20s %s\n", $$1, $$2}'

compile: ## Build the Xcode project
	@echo "Building $(PROJECT_NAME)..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		build

codesign: ## Code sign the built app
	@echo "Code signing $(PROJECT_NAME)..."
	codesign --force --deep --sign - "$(APP_BUNDLE)"

clean: ## Clean build artifacts
	@echo "Cleaning build..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		clean

test: ## Run test suite
	@echo "Running tests..."
	xcodebuild test -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-destination '$(TEST_DESTINATION)'

run-test: test ## Alias for test target

access: ## Open macOS Accessibility settings page
	@echo "Opening Accessibility settings..."
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

build: clean compile test codesign access ## full clean build/test/sign, then opens accessibility settings for add/remove dance
	@echo "Build complete!"

run: ## Open the app
	@echo "Opening $(PROJECT_NAME)..."
	open "$(APP_BUNDLE)"

.PHONY: help compile codesign clean test run-test access build run
