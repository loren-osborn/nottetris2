# Main Makefile for Not Tetris 2 Cross-Build System

# Pseudo targets: modal booleans that change build behavior.
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

# -- Platform Build Targets --
# Build for all platforms unless skipped.
# These are the target platforms for which files will be generated.
PLATFORMS_TO_BUILD := $(filter-out $(patsubst skip_%,%,$(call HAS_PSEUDO_TARGET,$(filter skip_%,$(PSEUDO_TARGETS)))),mac windows linux)

# -- Binary Outputs --
# Native binaries (pre-packaging) are separate targets with real output filenames.
# (For Windows, we produce separate 32-bit and 64-bit executables.)
BINARIES_TO_BUILD := $(strip \
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_mac.app/Contents/MacOS/$(GAME_NAME_NOSPACES),$\
    ) \
    $(if $(filter windows,$(PLATFORMS_TO_BUILD)),$\
        $(foreach bits,32 64,$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_$(bits).exe),$\
    ) \
    $(if $(filter linux,$(PLATFORMS_TO_BUILD)),$\
        $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux,$\
    )$\
)

# -- Package Outputs --
# These are the final installable packages which go in the dist directory.
PACKAGES_TO_BUILD := $(strip \
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-macos.zip,$\
    ) \
    $(if $(filter windows,$(PLATFORMS_TO_BUILD)),$\
        $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe,$\
    ) \
    $(if $(filter linux,$(PLATFORMS_TO_BUILD)),$\
        $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-$(VERSION)-x86_64.AppImage,$\
    ) \
)

# -- Default Goals --
# If no platforms are selected, then output the .love file in build.
DEFAULT_GOALS := $(strip \
    $(if $(PLATFORMS_TO_BUILD),,$(LOVE_FILE)) \
    $($(if $(call HAS_PSEUDO_TARGET,binaries_only),BINARIES,PACKAGES)_TO_BUILD) \
)

# Enforce macOS builds only on macOS.
$(if $(filter macOS,$(OS_TYPE)),$,$\
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(error The signing tools for macOS are only available on macOS platform. Please rerun make with the `skip_mac` option),$\
    )$\
)

# DIR_IF_MISSING ensures the directory exists by appending a trailing '.'.
DIR_IF_MISSING = $(shell [ -d $(dir $(1)) ] || echo $(dir $(1)).)

default: $(DEFAULT_GOALS)

### Required Tools and Assets

# Detect tools
SUPPORTED_DOWNLOADERS := wget curl
SUPPORTED_IMAGE_CONVERTERS := rsvg-convert convert
FOUND_DOWNLOADER := $(call FIND_FIRST_TOOL,$(SUPPORTED_DOWNLOADERS))
FOUND_IMAGE_CONVERTERS := $(call FIND_FIRST_TOOL,$(SUPPORTED_IMAGE_CONVERTERS))
DOWNLOADERS := $(if $(FOUND_DOWNLOADER),$(FOUND_DOWNLOADER),$(SUPPORTED_DOWNLOADERS))
IMAGE_CONVERTERS := $(if $(FOUND_IMAGE_CONVERTERS),$(FOUND_IMAGE_CONVERTERS),$(SUPPORTED_IMAGE_CONVERTERS))

# InnoSetup sometimes runs in Wine, so it needs special detection

# Define individual required tool and asset variables. Ensure these are defined before
# computing the global REQUIRED_TOOLS and REQUIRED_ASSETS.
REQUIRED_TOOLS_GENERIC := zip
REQUIRED_ASSETS_GENERIC :=

# macOS definitions:
REQUIRED_TOOLS_MAC_APP := $(IMAGE_CONVERTERS)
REQUIRED_ASSETS_MAC_APP := $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-macos.zip
REQUIRED_TOOLS_MAC_INSTALLER :=
REQUIRED_ASSETS_MAC_INSTALLER :=

# Windows definitions:
REQUIRED_TOOLS_WINDOWS_APP := $(IMAGE_CONVERTERS)
REQUIRED_ASSETS_WINDOWS_APP := $(foreach bits,32 64,$(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-win$(bits).zip)
# Always require Inno Setup; on non-Windows, also require wine.
REQUIRED_TOOLS_WINDOWS_INSTALLER := windows:C:/Program$(DOLLARS)(SPACE)Files$(DOLLARS)(SPACE)(x86)/Inno$(DOLLARS)(SPACE)Setup$(DOLLARS)(SPACE)6/Compil32.exe $(if $(filter Windows,$(OS_TYPE)),,wine)
REQUIRED_ASSETS_WINDOWS_INSTALLER :=

# Linux definitions:
REQUIRED_TOOLS_LINUX_APP :=
REQUIRED_ASSETS_LINUX_APP := $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-x86_64.AppImage
# For Linux installer, always use docker.
REQUIRED_TOOLS_LINUX_INSTALLER := docker $(IMAGE_CONVERTERS)
REQUIRED_ASSETS_LINUX_INSTALLER :=

# Combine required tools and assets from all platforms.
REQUIRED_TOOLS  := $(strip $(REQUIRED_TOOLS_GENERIC) $(foreach plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_TOOLS_$(plat)_$(artifact)))))
REQUIRED_ASSETS := $(strip $(REQUIRED_ASSETS_GENERIC) $(foreach plat,$(call TO_UPPER,$(PLATFORMS_TO_BUILD)),$(foreach artifact,APP $(if $(call HAS_PSEUDO_TARGET,binaries_only),,INSTALLER),$(REQUIRED_ASSETS_$(plat)_$(artifact)))))

# Download tools if required assets are missing.
MISSING_ASSETS := $(foreach file,$(REQUIRED_ASSETS),$(if $(wildcard $(file)),,$(file)))

ifneq ($(MISSING_ASSETS),)
    REQUIRED_TOOLS += $(DOWNLOADERS)
endif

# remove duplicates
REQUIRED_TOOLS := $(sort $(REQUIRED_TOOLS))

MISSING_TOOLS = $(call FIND_MISSING_TOOLS,$(REQUIRED_TOOLS))
ifneq ($(MISSING_TOOLS),)
    $(error The system is missing the following required tools: $(call GRAMATICAL_JOIN_LIST,$(MISSING_TOOLS),$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none))
endif

DOWNLOAD_URL_TO_FILE = $(if $(filter wget,$(FOUND_DOWNLOADER)),wget -q -O $(2) $(1),curl -fsSL -o $(2) $(1))
CONVERT_SVG_AT_SIZE_TO_ICON = $(if $(filter rsvg-convert,$(FOUND_IMAGE_CONVERTERS)),rsvg-convert -w $(2) -h $(3) $(1) -o $(4),convert -resize $(2)x$(3) $(1) $(4))

### Build Steps

# -- Build the .love Archive --
$(LOVE_FILE): $(REQUIRED_ASSETS_GENERIC) $(call DIR_IF_MISSING,$(LOVE_FILE)) $(shell find $(SOURCE_DIR))
	@echo "Creating LÖVE archive..."
	cd $(SOURCE_DIR) && command zip -9 -r $(realpath $(dir $(LOVE_FILE)))/$(notdir $(LOVE_FILE)) ./*
	@[ -f "$(LOVE_FILE)" ] && echo "LÖVE archive created at $(LOVE_FILE)"

# -- Ensure directories exist --
%/.:
	mkdir -p "$(patsubst %/.,%,$(subst $(DOLLARS)(SPACE),$(SPACE),$@))"

# -- Vendor Asset Download and Extraction --
$(eval $(foreach asset,$(filter $(VENDOR_DIR)/love2d/%,$(REQUIRED_ASSETS)),$(NEWLINE)$(asset): $(call DIR_IF_MISSING,$(asset))$(NEWLINE)$(TAB)command $(call DOWNLOAD_URL_TO_FILE,https://github.com/love2d/love/releases/download/$(REQUIRED_LOVE_VERSION)/$(notdir $(asset)),$(asset))$(NEWLINE)$(NEWLINE)))

# -- Icon Conversion Targets --
# Convert *.svg into PNG and ICO as needed.
$(BUILD_DIR)/icons/%_256.png $(BUILD_DIR)/icons/%_converted.ico: src/graphics/%.svg $(BUILD_DIR)/icons/.
	@echo "Converting $< to $(call TO_UPPER,$(patsubst .%,%,$(suffix $@)))..."
	$(call CONVERT_SVG_AT_SIZE_TO_ICON,$<,256,256,$@)
# (Additional conversion targets for platform-specific icons may be added as needed.)

# -- Native Binary Build Targets --
# Windows binary targets (native concatenation)
$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe: $(LOVE_FILE)
	@echo "Building Windows 32-bit binary..."
	mkdir -p $(dir $@)
	cat /usr/share/love/love.exe $(LOVE_FILE) > $@
	@echo "Created $@"

$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe: $(LOVE_FILE)
	@echo "Building Windows 64-bit binary..."
	mkdir -p $(dir $@)
	cat /usr/share/love/love.exe $(LOVE_FILE) > $@
	@echo "Created $@"

# macOS native app bundle target.
$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_mac.app/Contents/MacOS/$(GAME_NAME_NOSPACES): $(LOVE_FILE)
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Error: macOS build only on macOS."; exit 1; fi
	@echo "Building macOS App Bundle..."
	mkdir -p $(dir $@)
	cp $(LOVE_FILE) $@
	echo "APPL????" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/PkgInfo
	# Generate a basic Info.plist
	( \
	  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"; \
	  echo "<plist version=\"1.0\"><dict>"; \
	  echo "<key>CFBundleIdentifier</key><string>$(IDENTIFIER)</string>"; \
	  echo "</dict></plist>"; \
	) > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	@echo "Created $@"

# Linux binary target (the native Love2D binary plus .love)
$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux: $(LOVE_FILE) $(REQUIRED_ASSETS_LINUX_APP)
	@echo "Building Linux binary..."
	mkdir -p $(dir $@)
	# Extract the Love2D archive to a temporary location.
	unzip -q -o $(REQUIRED_ASSETS_LINUX_APP) -d $(BUILD_DIR)/linux_extracted
	# Assume the extracted Love binary is at $(BUILD_DIR)/linux_extracted/love;
	# copy it as the native binary.
	cp $(BUILD_DIR)/linux_extracted/love $@
	# Optionally, append the .love file or handle as per AppImage best practices.
	@echo "Created native Linux binary $@"

# -- Package (Installer) Build Targets --
# Windows Installer via Inno Setup: Two ways.
# 1. Native Windows build: when running on Windows, invoke innosetup directly.
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe innosetup.iss
	@echo "Building Windows installer natively..."
	@$(if $(filter Windows,$(OS_TYPE)), \
	     innosetup "$(DIST_DIR)/innosetup.iss", \
	     echo "Error: Native Inno Setup installer build only available on Windows.")
	@echo "Created installer at $@"

# 2. Windows Installer via Wine: when not on Windows, use Wine to run innosetup.
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.Wine.exe: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe innosetup.iss
	@echo "Building Windows installer via Wine..."
	@$(if $(filter-out Windows,$(OS_TYPE)), \
	     wine innosetup "$(DIST_DIR)/innosetup.iss", \
	     echo "Error: Wine-based installer build not applicable on Windows.")
	@echo "Created installer via Wine at $@"

# macOS DMG Build Target
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))-macos.zip: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_mac.app/Contents/MacOS/$(GAME_NAME_NOSPACES)
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping macOS build: Not running on macOS."; exit 0; fi
	@echo "Packaging macOS App Bundle..."
	zip -9 -r $@ $(BUILD_DIR)/macos
	@echo "Created macOS package at $@"

# Linux Installer: Create an AppImage package.
$(DIST_DIR)/NotTetris-$(VERSION)-x86_64.AppImage: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux $(BUILD_DIR)/icons/NotTetris2Icon_256.png
	@echo "Building Linux AppImage package..."
	# Create AppDir structure
	mkdir -p $(BUILD_DIR)/linux/AppDir/usr/bin
	# Copy the native Linux binary into the AppDir
	cp $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux $(BUILD_DIR)/linux/AppDir/usr/bin/love
	# Copy the .love file into the AppDir (or embed it in the binary per best practices)
	cp $(LOVE_FILE) $(BUILD_DIR)/linux/AppDir/usr/bin/$(GAME_NAME_LOWER_NOSPACES).love
	# Place the icon into the AppDir as expected by AppImage guidelines.
	cp $(BUILD_DIR)/icons/NotTetris2Icon_256.png $(BUILD_DIR)/linux/AppDir/usr/share/icons/hicolor/256x256/apps/NotTetris2.png
	# Generate the AppImage using appimagetool (assumes it is installed)
	appimagetool $(BUILD_DIR)/linux/AppDir $@
	@echo "Created Linux AppImage package at $@"

# -- Inno Setup Configuration Generation --
# Generate a basic Inno Setup script to be used by the Windows installer targets.
innosetup.iss: README.md LICENSE.txt $(BUILD_DIR)/icons/NotTetris2Icon_converted.ico NotTetris2Installer_artwork.bmp
	@echo "Generating Inno Setup configuration..."
	@mkdir -p $(DIST_DIR)
	@echo "; Inno Setup Script for $(GAME_NAME)" > $(DIST_DIR)/innosetup.iss
	@echo "AppName=$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "AppVersion=$(VERSION)" >> $(DIST_DIR)/innosetup.iss
	@echo "DefaultDirName={autopf}\\$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "DefaultGroupName=$(GAME_NAME)" >> $(DIST_DIR)/innosetup.iss
	@echo "OutputBaseFilename=$(call TO_TITLE_CASE,$(GAME_NAME))Installer" >> $(DIST_DIR)/innosetup.iss
	@echo "Compression=lzma" >> $(DIST_DIR)/innosetup.iss
	@echo "SetupIconFile=$(BUILD_DIR)/icons/NotTetris2Icon_converted.ico" >> $(DIST_DIR)/innosetup.iss
	@echo "WizardImageFile=$(VENDOR_DIR)/NotTetris2Installer_artwork.bmp" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe; DestDir: \"{app}\"; Flags: ignoreversion" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe; DestDir: \"{app}\"; Flags: ignoreversion" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: README.md; DestDir: \"{app}\"; Flags: isreadme" >> $(DIST_DIR)/innosetup.iss
	@echo "Source: LICENSE.txt; DestDir: \"{app}\"; Flags: isreadme" >> $(DIST_DIR)/innosetup.iss
	@echo "Inno Setup configuration generated at $(DIST_DIR)/innosetup.iss"

# -- Clean Target --
clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(VENDOR_DIR)

.PHONY: $(PSEUDO_TARGETS) clean

$(EVAL_PSEUDO_TARGETS_RULE)
