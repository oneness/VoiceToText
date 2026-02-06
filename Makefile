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

# printf formatting
BOLD := \033[1m
NORMAL := \033[0m

# Project settings
PROJECT_NAME := VoiceToText
SCHEME := VoiceToText
CONFIGURATION := Debug

# Get the actual app bundle path from xcodebuild
APP_BUNDLE := $(shell xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) -configuration $(CONFIGURATION) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$NF}')/$(PROJECT_NAME).app

help: ## Prints target: [dep1 dep1 ...]  and what it does
	@echo -e ${BOLD}
	@grep -E '^[a-zA-Z_-]+.*## .*$' $(MAKEFILE_LIST) | column -t -s"##"
	@echo -e ${NORMAL}

compile: ## Build the Xcode project
	@echo -e ${BOLD}Building $(PROJECT_NAME)...${NORMAL}
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		build

codesign: ## Code sign the built app
	@echo -e ${BOLD}Code signing $(PROJECT_NAME)...${NORMAL}
	codesign --force --deep --sign - "$(APP_BUNDLE)"

open: codesign ## Open the app
	@echo -e ${BOLD}Opening $(PROJECT_NAME)...${NORMAL}
	open "$(APP_BUNDLE)"

clean: ## Clean build artifacts
	@echo -e ${BOLD}Cleaning build...${NORMAL}
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		clean

build: clean compile ## Full clean build
	@echo -e ${BOLD}Build complete!${NORMAL}

run: clean compile codesign open ## Clean, build, code sign and run the app
	@echo -e ${BOLD}Running $(PROJECT_NAME)...${NORMAL}

.PHONY: help compile codesign open clean build run
