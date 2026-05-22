APP_NAME := Clank
EXECUTABLE := Clank
CONFIGURATION ?= release
BUILD_DIR := build
DIST_DIR := dist
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
ENTITLEMENTS := Clank.entitlements
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG_NAME := $(APP_NAME)-$(VERSION).dmg

.PHONY: build run bundle sign dmg release clean install-helper uninstall-helper

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
	if [ -d ".build/$(CONFIGURATION)/Clank_Clank.bundle" ]; then \
		cp -R ".build/$(CONFIGURATION)/Clank_Clank.bundle" "$(APP_DIR)/Contents/Resources/"; \
	fi
	chmod +x "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"

sign: bundle
	@echo "==> Ad-hoc codesign (bez Developer ID)"
	xattr -cr "$(APP_DIR)"
	codesign --force --deep --sign - --entitlements "$(ENTITLEMENTS)" "$(APP_DIR)"
	codesign --verify --deep --strict "$(APP_DIR)"
	@echo "Podpis OK (ad-hoc — Gatekeeper bedzie wymagal recznego dopuszczenia)"

dmg: sign
	@./scripts/build-dmg.sh "$(APP_DIR)" "$(DIST_DIR)/$(DMG_NAME)"

release: dmg
	@echo ""
	@echo "==> Wydanie gotowe: $(DIST_DIR)/$(DMG_NAME)"
	@ls -lh "$(DIST_DIR)/$(DMG_NAME)"

clean:
	rm -rf .build "$(BUILD_DIR)" "$(DIST_DIR)"

install-helper: sign
	@./scripts/install-helper.sh "$(APP_DIR)"

uninstall-helper:
	@./scripts/uninstall-helper.sh
