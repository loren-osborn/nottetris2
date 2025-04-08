
PSEUDO_TARGETS := install_tools skip_mac skip_windows skip_linux use_self_signed_cert binaries_only

include utils.mk

ifeq ($(OS_TYPE),Unknown)
	$(error I'm unable to detect your OS type! Aborting.)
endif



# Game Settings
GAME_NAME                := Not Tetris 2
GAME_NAME_NOSPACES       := $(subst $(SPACE),,$(GAME_NAME))
GAME_NAME_LOWER_NOSPACES := $(call TO_LOWER,$(GAME_NAME_NOSPACES))
VERSION                  := 2.1
REQUIRED_LOVE_VERSION    := 11.5
IDENTIFIER               := net.stabyourself.nottetris2
BUILD_DIR                := build
DIST_DIR                 := dist
SOURCE_DIR               := src
LOVE_FILE                := $(BUILD_DIR)/$(GAME_NAME_LOWER_NOSPACES).love

PLATFORMS_TO_BUILD := $(filter-out $(patsubst skip_%,%,$(call HAS_PSEUDO_TARGET,$(filter skip_%,$(PSEUDO_TARGETS)))),mac windows linux)

BINARIES_TO_BUILD := $(strip \
	$(if \
		$(filter mac,$(PLATFORMS_TO_BUILD)),$\
		$(BUILD_DIR)/bin/$(subst $(SPACE),$(DOLLARS)(SPACE),$(call TO_TITLE_CASE_WORDS,$(GAME_NAME))).app,$\
		$\
	) \
	$(if \
		$(filter windows,$(PLATFORMS_TO_BUILD)),$\
		$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME)).exe,$\
		$\
	) \
	$(if \
		$(filter linux,$(PLATFORMS_TO_BUILD)),$\
		$(BUILD_DIR)/bin/$(GAME_NAME_LOWER_NOSPACES),$\
		$\
	)$\
)

PACKAGES_TO_BUILD := $(strip \
	$(if \
		$(filter mac,$(PLATFORMS_TO_BUILD)),$\
		$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME)).dmg,$\
		$\
	) \
	$(if \
		$(filter windows,$(PLATFORMS_TO_BUILD)),$\
		$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe,$\
		$\
	) \
	$(if \
		$(filter linux,$(PLATFORMS_TO_BUILD)),$\
		$(foreach pkgtype,rpm deb,$(DIST_DIR)/$(GAME_NAME_LOWER_NOSPACES).$(pkgtype)),$\
		$\
	)$\
)

DEFAULT_GOALS := $(strip \
	$(if $(PLATFORMS_TO_BUILD),,$(LOVE_FILE)) \
	$($(if $(call HAS_PSEUDO_TARGET,binaries_only),BINARIES,PACKAGES)_TO_BUILD) \
)

$(if \
	$(filter macOS,$(OS_TYPE)),$\
	,$\
	$(if \
		$(filter mac,$(PLATFORMS_TO_BUILD)),$\
		$(error The signing tools for macOS are only available on macOS platform. Please rerun make with `skip_mac` option),$\
		$\
	)$\
)

default: $(DEFAULT_GOALS)

# Required Tools
REQUIRED_TOOLS_GENERIC := zip
REQUIRED_ASSETS_GENERIC :=
REQUIRED_TOOLS_MAC_APP :=
REQUIRED_ASSETS_MAC_APP :=
REQUIRED_TOOLS_MAC_INSTALLER :=
REQUIRED_ASSETS_MAC_INSTALLER :=
REQUIRED_TOOLS_WINDOWS_APP :=
REQUIRED_ASSETS_WINDOWS_APP :=
REQUIRED_TOOLS_WINDOWS_INSTALLER :=
REQUIRED_ASSETS_WINDOWS_INSTALLER :=
REQUIRED_TOOLS_LINUX_APP :=
REQUIRED_ASSETS_LINUX_APP :=
REQUIRED_TOOLS_LINUX_INSTALLER :=
REQUIRED_ASSETS_LINUX_INSTALLER :=

REQUIRED_TOOLS  := $(REQUIRED_TOOLS_GENERIC) $(foreach  plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_TOOLS_$(plat)_$(artifact))))
REQUIRED_ASSETS := $(REQUIRED_ASSETS_GENERIC) $(foreach plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_ASSETS_$(plat)_$(artifact))))

# Build LÖVE Archive
# removed dep: check-tools
$(LOVE_FILE): $(REQUIRED_ASSETS_GENERIC) $(dir $(LOVE_FILE)).
	@echo "Creating LÖVE archive..."
	cd $(SOURCE_DIR) && zip -9 -r $(realpath $(dir $(LOVE_FILE))) ./*
	@echo "LÖVE archive created at $(LOVE_FILE)"

%/.:
	mkdir -p "$(patsubst %/.,%,$(subst $(DOLLARS)(SPACE),$(SPACE),$@))"


# # Required Tools (macOS only)
# REQUIRED_TOOLS_MAC := hdiutil codesign xcrun

# # Combine lists conditionally
# REQUIRED_TOOLS := $(REQUIRED_TOOLS_GENERIC)
# ifneq ($(filter macOS,$(OS_TYPE)),)
#   REQUIRED_TOOLS += $(REQUIRED_TOOLS_MAC)
# endif

# # Detect Package Manager
# PACKAGE_MANAGER := $(shell which brew 2>/dev/null || which apt 2>/dev/null || which yum 2>/dev/null || which choco 2>/dev/null)
# INSTALL_CMD := $(if $(findstring brew, $(PACKAGE_MANAGER)), brew install, \
#               $(if $(findstring apt, $(PACKAGE_MANAGER)), sudo apt install -y, \
#               $(if $(findstring yum, $(PACKAGE_MANAGER)), sudo yum install -y, \
#               $(if $(findstring choco, $(PACKAGE_MANAGER)), choco install, \
#               echo "No package manager found! Install dependencies manually." && exit 1))))

# # Function to prompt for installation (as a single Bash string)
# define prompt_for_install
# 	echo "The following required tools are missing: $$MISSING_TOOLS"; \
# 	read -p "Would you like to install them? (y/N) " choice; \
# 	if [ "$$choice" = "y" ]; then $(INSTALL_CMD) $$MISSING_TOOLS; else \
# 		echo "Warning: Some tools are missing! Build may fail."; \
# 	fi
# endef

# # Check for required tools
# check-tools:
# 	@echo "Checking required tools..."
# 	@MISSING_TOOLS=""; \
# 	for tool in $(REQUIRED_TOOLS); do \
# 		if ! command -v $$tool >/dev/null; then \
# 			MISSING_TOOLS="$$MISSING_TOOLS $$tool"; \
# 		fi; \
# 	done; \
# 	if [ -n "$$MISSING_TOOLS" ]; then $(prompt_for_install); fi
# 	@echo "All required tools checked!"

# # Windows Build
# windows: $(LOVE_FILE)
# 	@echo "Building Windows Executable..."
# 	mkdir -p $(BUILD_DIR)/windows
# 	cat /usr/share/love/love.exe $(LOVE_FILE) > $(BUILD_DIR)/windows/$(GAME_NAME).exe
# 	cp -r /usr/share/love/*.dll $(BUILD_DIR)/windows/
# 	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-win.zip $(BUILD_DIR)/windows
# 	@echo "Windows Build Created: $(DIST_DIR)/$(GAME_NAME)-win.zip"

# # Linux Build
# linux: $(LOVE_FILE)
# 	@echo "Building Linux AppImage..."
# 	mkdir -p $(BUILD_DIR)/linux
# 	cp $(LOVE_FILE) $(BUILD_DIR)/linux/$(GAME_NAME).love
# 	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-linux.zip $(BUILD_DIR)/linux
# 	@echo "Linux Build Created: $(DIST_DIR)/$(GAME_NAME)-linux.zip"

# # macOS Build
# macos: $(LOVE_FILE)
# 	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping macOS build: Not running on macOS."; exit 0; fi
# 	@echo "Building macOS App Bundle..."
# 	mkdir -p $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/{MacOS,Resources}
# 	cp $(LOVE_FILE) $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/MacOS/$(GAME_NAME)
# 	echo "APPL????" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/PkgInfo
# 	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "<plist version=\"1.0\">" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "<dict>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "<key>CFBundleIdentifier</key>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "<string>$(IDENTIFIER)</string>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "</dict>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	echo "</plist>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
# 	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-macos.zip $(BUILD_DIR)/macos
# 	@echo "macOS Build Created: $(DIST_DIR)/$(GAME_NAME)-macos.zip"

# # macOS Signing
# sign-macos: macos
# 	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping signing: Not running on macOS."; exit 0; fi
# 	@echo "Signing macOS App..."
# 	codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name (XXXXXXXXXX)" $(BUILD_DIR)/macos/$(GAME_NAME).app

# # macOS Notarization (Placeholder)
# notarize-macos: sign-macos
# 	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping notarization: Not running on macOS."; exit 0; fi
# 	@echo "Notarizing macOS App (Requires Apple Developer Account)..."
# 	# Placeholder for Apple notarization command:
# 	# xcrun altool --notarize-app -f $(BUILD_DIR)/macos/$(GAME_NAME).zip --primary-bundle-id "$(IDENTIFIER)" --username "your@appleid.com" --password "@keychain:app-password"

# # macOS DMG Creation
# dmg: macos
# 	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping DMG creation: Not running on macOS."; exit 0; fi
# 	@echo "Creating macOS DMG..."
# 	hdiutil create -fs HFS+ -volname "$(GAME_NAME)" -srcfolder $(BUILD_DIR)/macos -ov $(DIST_DIR)/$(GAME_NAME).dmg

# Clean Build Artifacts
clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)

.PHONY: $(PSEUDO_TARGETS) check-tools windows linux macos sign-macos notarize-macos dmg clean

$(EVAL_PSEUDO_TARGETS_RULE)

