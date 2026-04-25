APP_NAME := Clank
EXECUTABLE := Clank
CONFIGURATION ?= release
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app

.PHONY: build run bundle clean install-sudoers uninstall-sudoers

build:
	swift build -c $(CONFIGURATION)

run:
	swift run $(EXECUTABLE)

bundle: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp ".build/$(CONFIGURATION)/$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"
	cp "Info.plist" "$(APP_DIR)/Contents/Info.plist"
	cp "Sources/Clank/Resources/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	if [ -d ".build/$(CONFIGURATION)/Clank_Clank.bundle" ]; then cp -R ".build/$(CONFIGURATION)/Clank_Clank.bundle" "$(APP_DIR)/"; cp -R ".build/$(CONFIGURATION)/Clank_Clank.bundle" "$(APP_DIR)/Contents/Resources/"; fi
	chmod +x "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"

clean:
	rm -rf .build "$(BUILD_DIR)"

install-sudoers:
	@echo "Installing sudoers rule for $(USER)... (you may be prompted for your password)"
	@sudo sh -c 'echo "$(USER) ALL=(ALL) NOPASSWD: $$(pwd)/.build/debug/$(EXECUTABLE), $$(pwd)/.build/release/$(EXECUTABLE), $$(pwd)/$(APP_DIR)/Contents/MacOS/$(EXECUTABLE), /Applications/$(APP_NAME).app/Contents/MacOS/$(EXECUTABLE), $$(pwd)/.build/arm64-apple-macosx/debug/$(EXECUTABLE), $$(pwd)/.build/arm64-apple-macosx/release/$(EXECUTABLE)" > /etc/sudoers.d/clank'
	@sudo chmod 0440 /etc/sudoers.d/clank
	@echo "Done! /etc/sudoers.d/clank has been created."

uninstall-sudoers:
	@echo "Removing sudoers rule for $(USER)... (you may be prompted for your password)"
	@sudo rm -f /etc/sudoers.d/clank
	@echo "Done! /etc/sudoers.d/clank has been removed."
