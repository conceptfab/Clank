APP_NAME := Clank
EXECUTABLE := Clank
CONFIGURATION ?= release
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app

.PHONY: build run bundle clean

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
