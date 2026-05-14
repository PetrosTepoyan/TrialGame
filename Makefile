# Three Towers — iOS / TestFlight build helpers.
#
# Prereqs (once):
#   - Godot 4.6.2 with iOS export templates installed
#     (Editor -> Manage Export Templates, or already on disk under
#      ~/Library/Application Support/Godot/export_templates/4.6.2.stable/)
#   - Xcode 15+ with command-line tools
#   - fastlane (gem install fastlane)
#   - cp fastlane/.env.example fastlane/.env and fill it in
#   - App record created in App Store Connect with bundle id
#     com.petrostepoyan.threetowers

GODOT := /Applications/Godot.app/Contents/MacOS/Godot
EXPORT_DIR := ios-export
XCODEPROJ := $(EXPORT_DIR)/ThreeTowers.xcodeproj

.PHONY: help export-ios export-ios-release open-xcode testflight clean-ios

help:
	@echo "Three Towers — iOS targets"
	@echo "  make export-ios          Godot exports debug-config Xcode project to $(EXPORT_DIR)/"
	@echo "  make export-ios-release  Godot exports release-config Xcode project to $(EXPORT_DIR)/"
	@echo "  make open-xcode          Open the exported Xcode project"
	@echo "  make testflight          fastlane upload_testflight (requires fastlane/.env)"
	@echo "  make clean-ios           Remove $(EXPORT_DIR)/"

$(EXPORT_DIR):
	mkdir -p $(EXPORT_DIR)

export-ios: $(EXPORT_DIR)
	$(GODOT) --headless --path . --export-debug "iOS" $(XCODEPROJ)

export-ios-release: $(EXPORT_DIR)
	$(GODOT) --headless --path . --export-release "iOS" $(XCODEPROJ)

open-xcode:
	@if [ ! -d "$(XCODEPROJ)" ]; then \
		echo "No Xcode project at $(XCODEPROJ). Run 'make export-ios' first."; \
		exit 1; \
	fi
	open $(XCODEPROJ)

testflight:
	@if [ ! -d "$(XCODEPROJ)" ]; then \
		echo "No Xcode project at $(XCODEPROJ). Run 'make export-ios-release' first."; \
		exit 1; \
	fi
	@if [ ! -f fastlane/.env ]; then \
		echo "fastlane/.env not found. Copy fastlane/.env.example and fill in real values."; \
		exit 1; \
	fi
	set -a; . fastlane/.env; set +a; cd . && fastlane ios upload_testflight

clean-ios:
	rm -rf $(EXPORT_DIR)
