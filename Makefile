REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BIN := $(REPO_DIR)/lgtv-hotkeys
LABEL := com.lgtv.hotkeys
PLIST := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG := /tmp/lgtv-hotkeys.log

.PHONY: build install-agent uninstall-agent clean

build:
	@swiftc -O -o lgtv-hotkeys Sources/lgtv-hotkeys.swift
	@./lgtv-hotkeys selftest

install-agent: build
	@mkdir -p $(HOME)/Library/LaunchAgents
	@sed -e "s|__BINARY_PATH__|$(BIN)|g" -e "s|__LOG_PATH__|$(LOG)|g" launchagents/$(LABEL).plist.template > $(PLIST)
	@echo "Wrote $(PLIST)"
	@-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(PLIST)
	@echo "LaunchAgent loaded; log: $(LOG)"
	@echo "If the TV is unpaired, press a hotkey and accept the prompt on the TV"

uninstall-agent:
	@-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	@rm -f $(PLIST)
	@echo "LaunchAgent removed"

clean:
	rm -f lgtv-hotkeys
