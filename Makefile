# Pseudo targets: these are modal flags that alter build behavior without building files.
PSEUDO_TARGETS := skip_mac skip_windows skip_linux use_self_signed_cert binaries_only
#PSEUDO_TARGETS += allow_tools_install

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
VENDOR_DIR               := vendor
BUILD_DIR                := build
DIST_DIR                 := dist
SOURCE_DIR               := src
LOVE_FILE                := $(BUILD_DIR)/$(GAME_NAME_LOWER_NOSPACES).love

# Define supported platforms for cross-release builds.
# These platforms are built unless they are skipped via pseudo targets.
PLATFORMS_TO_BUILD := $(filter-out $(patsubst skip_%,%,$(call HAS_PSEUDO_TARGET,$(filter skip_%,$(PSEUDO_TARGETS)))),mac windows linux)

BINARIES_TO_BUILD := $(strip \
	$(if \
		$(filter mac,$(PLATFORMS_TO_BUILD)),$\
		$(BUILD_DIR)/bin/$(subst $(SPACE),$(DOLLARS)(SPACE),$(call TO_TITLE_CASE_WORDS,$(GAME_NAME))).app,$\
		$\
	) \
	$(if \
		$(filter windows,$(PLATFORMS_TO_BUILD)),$\
		$(foreach bits,32 64,$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_$(bits).exe),$\
		$\
	) \
	$(if \
		$(filter linux,$(PLATFORMS_TO_BUILD)),$\
		$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-$(VERSION)-x86_64.AppImage,$\
		$\
	) \
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
		$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-$(VERSION)-x86_64.AppImage,$\
		$\
	) \
)

DEFAULT_GOALS := $(strip \
	$(if $(PLATFORMS_TO_BUILD),,$(LOVE_FILE)) \
	$($(if $(call HAS_PSEUDO_TARGET,binaries_only),BINARIES,PACKAGES)_TO_BUILD) \
)

# Enforce macOS-specific builds: if building for macOS, must run on macOS.
$(if \
	$(filter macOS,$(OS_TYPE)),$\
	,$\
	$(if \
		$(filter mac,$(PLATFORMS_TO_BUILD)),$\
		$(error The signing tools for macOS are only available on macOS platform. Please rerun make with the `skip_mac` option),$\
		$\
	)$\
)

DIR_IF_MISSING = $(shell [ -d $(dir $(1)) ] || echo $(dir $(1)).)

default: $(DEFAULT_GOALS)

### Required Tools and Assets Definitions

REQUIRED_TOOLS_GENERIC := zip
REQUIRED_ASSETS_GENERIC :=

# macOS definitions
REQUIRED_TOOLS_MAC_APP :=
REQUIRED_ASSETS_MAC_APP := $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-macos.zip
REQUIRED_TOOLS_MAC_INSTALLER :=
REQUIRED_ASSETS_MAC_INSTALLER :=

# Windows definitions
REQUIRED_TOOLS_WINDOWS_APP :=
REQUIRED_ASSETS_WINDOWS_APP := $(foreach bits,32 64,$(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-win$(bits).zip)
REQUIRED_TOOLS_WINDOWS_INSTALLER := innosetup $(if $(filter Windows,$(OS_TYPE)),,wine)
REQUIRED_ASSETS_WINDOWS_INSTALLER :=

# Linux definitions
REQUIRED_TOOLS_LINUX_APP :=
REQUIRED_ASSETS_LINUX_APP := $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-linux.zip
REQUIRED_TOOLS_LINUX_INSTALLER := $(if $(filter Unix/Linux,$(OS_TYPE)),,docker)
REQUIRED_ASSETS_LINUX_INSTALLER :=

# Combine required tools and assets from all platforms
REQUIRED_TOOLS  := $(strip $(REQUIRED_TOOLS_GENERIC) $(foreach plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_TOOLS_$(plat)_$(artifact)))))
REQUIRED_ASSETS := $(strip $(REQUIRED_ASSETS_GENERIC) $(foreach plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_ASSETS_$(plat)_$(artifact)))))

MISSING_ASSETS := $(foreach file,$(REQUIRED_ASSETS),$(if $(wildcard $(file)),,$(file)))

SUPPORTED_DOWNLOADERS := wget curl
FOUND_DOWNLOADER := $(call FIND_FIRST_TOOL,$(SUPPORTED_DOWNLOADERS))

ifneq ($(MISSING_ASSETS),)
    REQUIRED_TOOLS += $(if $(FOUND_DOWNLOADER),$(FOUND_DOWNLOADER),$(SUPPORTED_DOWNLOADERS))
endif

MISSING_TOOLS = $(call FIND_MISSING_TOOLS,$(REQUIRED_TOOLS))

ifneq ($(MISSING_TOOLS),)
    # I'm hoping to add some package installation support here, but for now, just error out:
    $(error The system is missing the following required tools: $(call GRAMATICAL_JOIN_LIST,$(MISSING_TOOLS),$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none))
endif

DOWNLOAD_URL_TO_FILE = $(if $(filter wget,$(FOUND_DOWNLOADER)),wget -q -O $(2) $(1),curl -fsSL -o $(2) $(1))

### Build LÖVE Archive
# Removed dependency check: no longer using check-tools; MISSING_TOOLS replaces that.
$(LOVE_FILE): $(REQUIRED_ASSETS_GENERIC) $(call DIR_IF_MISSING,$(LOVE_FILE)) $(shell find $(SOURCE_DIR))
	@echo "Creating LÖVE archive..."
	cd $(SOURCE_DIR) && command zip -9 -r $(realpath $(dir $(LOVE_FILE)))/$(notdir $(LOVE_FILE)) ./*
	@[ -f "$(LOVE_FILE)" ] && echo "LÖVE archive created at $(LOVE_FILE)"

%/.:
	mkdir -p "$(patsubst %/.,%,$(subst $(DOLLARS)(SPACE),$(SPACE),$@))"

# Vendor asset download and extraction for love2d archives.
$(eval $(foreach asset,$(filter $(VENDOR_DIR)/love2d/%,$(REQUIRED_ASSETS)),$(NEWLINE)$(asset): $(call DIR_IF_MISSING,$(asset))$(NEWLINE)$(TAB)command $(call DOWNLOAD_URL_TO_FILE,https://github.com/love2d/love/releases/download/$(REQUIRED_LOVE_VERSION)/$(notdir $(asset)),$(asset))$(NEWLINE)$(NEWLINE)))

### Installer Configuration Generation

# Inno Setup configuration: generates innosetup.iss in the dist directory.
innosetup.iss: $(wildcard README.md LICENSE.txt NotTetris2Icon.svg)
	@echo "Generating Inno Setup configuration..."
	@echo "; Inno Setup Script for $(GAME_NAME)" > $(DIST_DIR)/innosetup.iss
	@echo "AppName=$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "AppVersion=$(VERSION)" >> $(DIST_DIR)/innosetup.iss
	@echo "DefaultDirName={autopf}\\$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "DefaultGroupName=$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "OutputBaseFilename=$(call TO_TITLE_CASE,$(GAME_NAME))Installer" >> $(DIST_DIR)/innosetup.iss
	@echo "Compression=lzma" >> $(DIST_DIR)/innosetup.iss
	@echo "SetupIconFile=$(VENDOR_DIR)/NotTetris2Icon_converted.ico" >> $(DIST_DIR)/innosetup.iss
	@echo "WizardImageFile=$(VENDOR_DIR)/NotTetris2Installer_artwork.bmp" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe; DestDir: \"{app}\"; Flags: ignoreversion" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe; DestDir: \"{app}\"; Flags: ignoreversion" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: README.md; DestDir: \"{app}\"; Flags: isreadme" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: LICENSE.txt; DestDir: \"{app}\"; Flags: isreadme" >> $(DIST_DIR)/innosetup.iss
	@echo "Inno Setup configuration generated at $(DIST_DIR)/innosetup.iss"

### Platform Build Targets

# Windows Build
windows: $(LOVE_FILE)
	@echo "Building Windows Executable..."
	mkdir -p $(BUILD_DIR)/windows
	# Concatenate love.exe with the .love file to form a self-contained executable.
	cat /usr/share/love/love.exe $(LOVE_FILE) > $(BUILD_DIR)/windows/$(GAME_NAME_LOWER_NOSPACES)_32.exe
	# Copy required DLLs (assuming they are installed in /usr/share/love/)
	cp -r /usr/share/love/*.dll $(BUILD_DIR)/windows/
	zip -9 -r $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe $(BUILD_DIR)/windows
	@echo "Windows Installer Created: $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe"

# macOS Build
macos: $(LOVE_FILE)
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping macOS build: Not running on macOS."; exit 0; fi
	@echo "Building macOS App Bundle..."
	mkdir -p $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/{MacOS,Resources}
	cp $(LOVE_FILE) $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/MacOS/$(GAME_NAME)
	echo "APPL????" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/PkgInfo
	# Generate a basic Info.plist using the IDENTIFIER.
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<plist version=\"1.0\"><dict>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<key>CFBundleIdentifier</key>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<string>$(IDENTIFIER)</string>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "</dict></plist>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	zip -9 -r $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-macos.zip $(BUILD_DIR)/macos
	@echo "macOS Build Created: $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-macos.zip"

# Linux Build: AppImage
linux: $(LOVE_FILE)
	@echo "Building Linux AppImage..."
	# Create an AppDir structure according to Love2D distribution guidelines.
	mkdir -p $(BUILD_DIR)/linux/AppDir/usr/bin
	# Extract the Love2D archive if necessary. (Assumes unzip is available.)
	unzip -q -o $(REQUIRED_ASSETS_LINUX_APP) -d $(BUILD_DIR)/linux/AppDir/usr/bin
	# Assume the Love binary is now located in $(BUILD_DIR)/linux/AppDir/usr/bin/love.
	# Embed the .love file in the appropriate location (best practice: as an external file).
	cp $(LOVE_FILE) $(BUILD_DIR)/linux/AppDir/usr/bin/$(GAME_NAME_LOWER_NOSPACES).love
	# (Optionally, additional steps can append the .love file to the Love binary if desired.)
	# Convert NotTetris2Icon.svg to PNG for the AppImage icon.
	$(if $(shell command -v rsvg-convert 2>/dev/null),\
	  rsvg-convert -w 256 -h 256 NotTetris2Icon.svg -o $(BUILD_DIR)/linux/NotTetris2Icon.png, \
	  convert -resize 256x256 NotTetris2Icon.svg $(BUILD_DIR)/linux/NotTetris2Icon.png)
	# Generate the AppImage using appimagetool (assumed to be available).
	appimagetool $(BUILD_DIR)/linux/AppDir $(DIST_DIR)/NotTetris-$(VERSION)-x86_64.AppImage
	@echo "Linux AppImage Created: $(DIST_DIR)/NotTetris-$(VERSION)-x86_64.AppImage"

### Clean and Other Targets

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(VENDOR_DIR)

.PHONY: $(PSEUDO_TARGETS) windows macos linux clean
$(EVAL_PSEUDO_TARGETS_RULE)
