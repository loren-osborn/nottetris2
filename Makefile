# Main Makefile for Not Tetris 2 Cross-Build System

# Pseudo targets: modal booleans that change build behavior.
PSEUDO_TARGETS := skip_mac skip_windows skip_linux use_self_signed_cert binaries_only
#PSEUDO_TARGETS += allow_tools_install

include utils.mk

ifeq ($(OS_TYPE),Unknown)
	$(error I'm unable to detect your OS type! Aborting.)
endif

# Game Settings
GAME_NAME                   := Not Tetris 2
GAME_NAME_NOSPACES          := $(subst $(SPACE),,$(GAME_NAME))
GAME_NAME_LOWER_NOSPACES    := $(call TO_LOWER,$(GAME_NAME_NOSPACES))
VERSION                     := 2.1
REQUIRED_LOVE_VERSION       := 11.5
IDENTIFIER                  := net.stabyourself.nottetris2
VENDOR_DIR                  := vendor
BUILD_DIR                   := build
DIST_DIR                    := dist
SOURCE_DIR                  := src
LOVE_FILE                   := $(BUILD_DIR)/$(GAME_NAME_LOWER_NOSPACES).love
GENERATED_FILES             := $(BUILD_DIR) src/graphics/NotTetris2Icon.png

MACOS_APP_BUNDLE            := $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME)).app
MACOS_APP_ICON_BASENAME     := $(call TO_TITLE_CASE,$(GAME_NAME))Icon
MACOS_APP_BUNDLE_BINARY     := $(GAME_NAME_LOWER_NOSPACES)
MACOS_APP_BUNDLE_PLIST_DICT := \
    CFBundleExecutable:$(MACOS_APP_BUNDLE_BINARY) \
    CFBundleIdentifier:$(IDENTIFIER) \
    CFBundleName:$(call TO_TITLE_CASE,$(GAME_NAME)) \
    CFBundleVersion:1.0 \
    CFBundleIconFile:$(MACOS_APP_ICON_BASENAME) \
    CFBundlePackageType:APPL

define MACOS_PLIST_TEMPLATE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
$(1)
</dict>
</plist>
endef

MACOS_APP_BUNDLE_PLIST := $(call \
  MACOS_PLIST_TEMPLATE,$\
  $(subst \
    $(DOLLARS)(SPACE),$\
    $(SPACE),$\
    $(subst \
      $(SPACE),$\
      $(NEWLINE),$\
      $(foreach \
        pair,$\
        $(MACOS_APP_BUNDLE_PLIST_DICT),$\
        $(DOLLARS)(SPACE)$(DOLLARS)(SPACE)<key>$(call GET_FIELD_FROM_BLOBS,1,$(pair))</key> $\
        $(DOLLARS)(SPACE)$(DOLLARS)(SPACE)<string>$(call GET_FIELD_FROM_BLOBS,2,$(pair))</string>$\
      )$\
    )$\
  )$\
)

# Step 1: Compute icon blobs using Bash.
# Each blob is in the format: logical:base:next_logical:retina
# For n from 4 to 9, this yields:
#   4:16:5:32 5:32:6:64 6:64:7:128 7:128:8:256 8:256:9:512 9:512:10:1024
MACOS_ICON_SIZE_BLOBS := $(shell bash -c 'for n in {4..9}; do echo -n "$$n:$$((1<<$$n)):$$((n+1)):$$((1<<(n+1))) "; done')

ALL_MACOS_ICON_SIZE_IDS := $(sort $(call GET_FIELD_FROM_BLOBS,1,$(MACOS_ICON_SIZE_BLOBS)) $(call GET_FIELD_FROM_BLOBS,3,$(MACOS_ICON_SIZE_BLOBS)))

ALL_MACOS_ICON_BLOBS := $(foreach id,$(ALL_MACOS_ICON_SIZE_IDS),$(id):$(sort $(call GET_FIELD_FROM_BLOBS,2,$(call GET_BLOBS_MATCHING_FIELD,1,$(id),$(MACOS_ICON_SIZE_BLOBS))) $(call GET_FIELD_FROM_BLOBS,4,$(call GET_BLOBS_MATCHING_FIELD,3,$(id),$(MACOS_ICON_SIZE_BLOBS)))):$(subst $(SPACE),$(COMMA),$(sort \
  $(if $(sort $(call GET_BLOBS_MATCHING_FIELD,1,$(id),$(MACOS_ICON_SIZE_BLOBS))),icon_$(call GET_FIELD_FROM_BLOBS,2,$(call GET_BLOBS_MATCHING_FIELD,1,$(id),$(MACOS_ICON_SIZE_BLOBS)))x$(call GET_FIELD_FROM_BLOBS,2,$(call GET_BLOBS_MATCHING_FIELD,1,$(id),$(MACOS_ICON_SIZE_BLOBS))).png,) \
  $(if $(sort $(call GET_BLOBS_MATCHING_FIELD,3,$(id),$(MACOS_ICON_SIZE_BLOBS))),icon_$(call GET_FIELD_FROM_BLOBS,2,$(call GET_BLOBS_MATCHING_FIELD,3,$(id),$(MACOS_ICON_SIZE_BLOBS)))x$(call GET_FIELD_FROM_BLOBS,2,$(call GET_BLOBS_MATCHING_FIELD,3,$(id),$(MACOS_ICON_SIZE_BLOBS)))@2x.png,) \
)))


# -- Platform Build Targets --
# Build for all platforms unless skipped.
# These are the target platforms for which files will be generated.
DEFAULT_PLATFORMS_TO_BUILD := $(filter-out $(patsubst skip_%,%,$(call HAS_PSEUDO_TARGET,$(filter skip_%,$(PSEUDO_TARGETS)))),mac windows linux)
PLATFORMS_TO_BUILD := $(DEFAULT_PLATFORMS_TO_BUILD)

# -- Binary Outputs --
# Native binaries (pre-packaging) are separate targets with real output filenames.
# (For Windows, we produce separate 32-bit and 64-bit executables.)
DEFAULT_BINARIES_TO_BUILD := $(strip \
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(MACOS_APP_BUNDLE),$\
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
DEFAULT_PACKAGES_TO_BUILD := $(strip \
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME)).dmg,$\
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
    $(DEFAULT_$(if $(call HAS_PSEUDO_TARGET,binaries_only),BINARIES,PACKAGES)_TO_BUILD) \
)

# Enforce macOS builds only on macOS.
$(if $(filter macOS,$(OS_TYPE)),$,$\
    $(if $(filter mac,$(PLATFORMS_TO_BUILD)),$\
        $(error The signing tools for macOS are only available on macOS platform. Please rerun make with the `skip_mac` option),$\
    )$\
)

all default: $(DEFAULT_GOALS)

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
REQUIRED_TOOLS_MAC_APP := $(IMAGE_CONVERTERS) iconutil
REQUIRED_ASSETS_MAC_APP := $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-macos.zip
REQUIRED_TOOLS_MAC_INSTALLER :=
REQUIRED_ASSETS_MAC_INSTALLER :=

# Windows definitions:
REQUIRED_TOOLS_WINDOWS_APP := $(if $(filter Windows,$(OS_TYPE)),,wine) $(IMAGE_CONVERTERS) windows:rcedit
REQUIRED_ASSETS_WINDOWS_APP := $(foreach bits,32 64,$(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-win$(bits).zip)
# Always require Inno Setup; on non-Windows, also require wine.
# REQUIRED_TOOLS_WINDOWS_INSTALLER := windows:C:/Program$(DOLLARS)(SPACE)Files$(DOLLARS)(SPACE)(x86)/Inno$(DOLLARS)(SPACE)Setup$(DOLLARS)(SPACE)6/Compil32.exe $(if $(filter Windows,$(OS_TYPE)),,wine)
REQUIRED_TOOLS_WINDOWS_INSTALLER :=
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

DOWNLOAD_URL_TO_FILE = $(if $(filter wget,$(FOUND_DOWNLOADER)),wget -v -O $(2) $(1),curl -fsSL -o $(2) $(1))
CONVERT_SVG_AT_SIZE_TO_IMAGE = $(if $(filter rsvg-convert,$(FOUND_IMAGE_CONVERTERS)),rsvg-convert -w $(2) -h $(3) $(1) -o $(4),convert -resize $(2)x$(3) $(1) $(4))

### Build Steps

# -- Build the .love Archive --
$(LOVE_FILE): $(REQUIRED_ASSETS_GENERIC) $(shell find $(SOURCE_DIR)) src/graphics/NotTetris2Icon.png Makefile
	$(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(dir $@))
	@echo "Creating LÖVE archive..."
	cd $(SOURCE_DIR) && command zip -9 -r $(realpath $(dir $(LOVE_FILE)))/$(notdir $(LOVE_FILE)) ./*
	@[ -f "$@" ] && echo "LÖVE archive created at $@"

# -- Vendor Asset Download and Extraction --
$(eval $(foreach asset,$(filter $(VENDOR_DIR)/love2d/%,$(REQUIRED_ASSETS)),$(NEWLINE)$(asset): Makefile$(NEWLINE)$(TAB)$(DOLLARS)(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(DOLLARS)(dir $(DOLLARS)@))$(NEWLINE)$(TAB)command $(call DOWNLOAD_URL_TO_FILE,https://github.com/love2d/love/releases/download/$(REQUIRED_LOVE_VERSION)/$(notdir $(asset)),$(asset))$(NEWLINE)$(NEWLINE)))

# -- Icon Conversion Targets --
# Convert *.svg into PNG and ICO as needed.
$(BUILD_DIR)/icons/%_256.png $(BUILD_DIR)/icons/%_converted.ico src/graphics/%.png: src/graphics/%.svg $(shell [ -d "$(BUILD_DIR)/icons" ] || echo "$(BUILD_DIR)/icons/.") Makefile
	@echo "Converting $< to $(call TO_UPPER,$(patsubst .%,%,$(suffix $@)))..."
	$(call CONVERT_SVG_AT_SIZE_TO_IMAGE,$<,256,256,$@)
	@[ -f $@ ] && echo "Created $@"
# (Additional conversion targets for platform-specific icons may be added as needed.)

$(eval \
	$(foreach \
		icon_blob,$\
		$(ALL_MACOS_ICON_BLOBS),$\
		$(NEWLINE)$\
			$(BUILD_DIR)/icons/$(MACOS_APP_ICON_BASENAME).iconset/$(firstword $(subst $(COMMA),$(SPACE),$(call GET_FIELD_FROM_BLOBS,3,$(icon_blob)))):$(SPACE)src/graphics/NotTetris2Icon.svg Makefile$(NEWLINE)$\
			$(TAB)$(DOLLARS)(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(DOLLARS)(dir $(DOLLARS)@))$(NEWLINE)$\
			$(TAB)$(call CONVERT_SVG_AT_SIZE_TO_IMAGE,$(DOLLARS)<,$(call GET_FIELD_FROM_BLOBS,2,$(icon_blob)),$(call GET_FIELD_FROM_BLOBS,2,$(icon_blob)),$(DOLLARS)@)$(NEWLINE)$\
	)$\
	$(foreach \
		icon_blob,$\
		$(ALL_MACOS_ICON_BLOBS),$\
		$(if \
			$(findstring $(COMMA),$(icon_blob)),$\
		  $(NEWLINE)$\
			  $(BUILD_DIR)/icons/$(MACOS_APP_ICON_BASENAME).iconset/$(word 2,$(subst $(COMMA),$(SPACE),$(call GET_FIELD_FROM_BLOBS,3,$(icon_blob)))):$(SPACE)$(BUILD_DIR)/icons/$(MACOS_APP_ICON_BASENAME).iconset/$(firstword $(subst $(COMMA),$(SPACE),$(call GET_FIELD_FROM_BLOBS,3,$(icon_blob)))) Makefile$(NEWLINE)$\
			  $(TAB)cp $(DOLLARS)< $(DOLLARS)@$(NEWLINE),$\
			$\
		)$\
	)$\
	$(NEWLINE)$\
	$(MACOS_APP_BUNDLE)/Contents/Resources/$(MACOS_APP_ICON_BASENAME).icns: $(foreach file,$(subst $(COMMA),$(SPACE),$(call GET_FIELD_FROM_BLOBS,3,$(ALL_MACOS_ICON_BLOBS))),$(BUILD_DIR)/icons/$(MACOS_APP_ICON_BASENAME).iconset/$(file)) Makefile$(NEWLINE)$\
		$(TAB)$(DOLLARS)(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(DOLLARS)(dir $(DOLLARS)@))$(NEWLINE)$\
		$(TAB)iconutil -c icns $(BUILD_DIR)/icons/$(MACOS_APP_ICON_BASENAME).iconset -o $(DOLLARS)@$(NEWLINE)$\
	$(NEWLINE)$\
)



# -- Native Binary Build Targets --
# Windows binary targets (native concatenation)
$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe: $(LOVE_FILE) Makefile
	@echo "Building Windows 32-bit binary..."
	mkdir -p $(dir $@)
	cat /usr/share/love/love.exe $(LOVE_FILE) > $@
	@[ -f $@ ] && echo "Created $@"

$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe: $(LOVE_FILE) Makefile
	@echo "Building Windows 64-bit binary..."
	mkdir -p $(dir $@)
	cat /usr/share/love/love.exe $(LOVE_FILE) > $@
	@[ -f $@ ] && echo "Created $@"

# This includes $(MACOS_APP_BUNDLE)/Contents/Frameworks: but grouped targets aren't supported in make 3.81
$(MACOS_APP_BUNDLE)/Contents/MacOS/$(MACOS_APP_BUNDLE_BINARY): $(LOVE_FILE) $(VENDOR_DIR)/love2d/love-$(REQUIRED_LOVE_VERSION)-macos.zip Makefile
	$(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(dir $@))
	(rm -rf $(BUILD_DIR)/extract/macOS_tmp $(MACOS_APP_BUNDLE)/Contents/Frameworks && mkdir -p $(BUILD_DIR)/extract/macOS_tmp && unzip -o $(VENDOR_DIR)/love2d/love-11.5-macos.zip -d $(BUILD_DIR)/extract/macOS_tmp) || (rm -rf $(BUILD_DIR)/extract/macOS_tmp ; exit 1)
	mv $(BUILD_DIR)/extract/macOS_tmp/love.app/Contents/Frameworks $(MACOS_APP_BUNDLE)/Contents || (rm -rf $(BUILD_DIR)/extract/macOS_tmp $(MACOS_APP_BUNDLE)/Contents/Frameworks ; exit 1)
	cat $(BUILD_DIR)/extract/macOS_tmp/love.app/Contents/MacOS/love $(LOVE_FILE) > $@ || (rm -rf $(BUILD_DIR)/extract/macOS_tmp $(MACOS_APP_BUNDLE)/Contents/Frameworks $@ ; exit 1)
	@# make file executable:
	chmod $(shell printf "%03o" $$(( 8#$$($(GET_FILE_PERMISSIONS_OCTAL) $(LOVE_FILE)) | ((8#$$($(GET_FILE_PERMISSIONS_OCTAL) $(LOVE_FILE)) & 0444) >> 2) ))) $@ || (rm -rf $(BUILD_DIR)/extract/macOS_tmp $(MACOS_APP_BUNDLE)/Contents/Frameworks $@ ; exit 1)
	rm -rf $(BUILD_DIR)/extract/macOS_tmp
	@[ -f $@ ] && echo "Copied $(MACOS_APP_BUNDLE)/Contents/Frameworks and Assembled $@"

$(MACOS_APP_BUNDLE)/Contents/PkgInfo: Makefile
	$(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(dir $@))
	echo "APPL????" > $@
	@[ -f $@ ] && echo "Created $@"

$(MACOS_APP_BUNDLE)/Contents/Info.plist: Makefile
	$(call RECIPE_LINE_CREATE_DIR_IF_MISSING,$(dir $@))
	@# Generate a basic Info.plist
	( echo '$(subst $(NEWLINE),' ; echo ',$(MACOS_APP_BUNDLE_PLIST))' ) > $@
	@[ -f $@ ] && echo "Created $@"

$(MACOS_APP_BUNDLE): \
    $(MACOS_APP_BUNDLE)/Contents/Info.plist \
    $(MACOS_APP_BUNDLE)/Contents/PkgInfo \
    $(MACOS_APP_BUNDLE)/Contents/MacOS/$(MACOS_APP_BUNDLE_BINARY) \
    $(MACOS_APP_BUNDLE)/Contents/Resources/$(MACOS_APP_ICON_BASENAME).icns \
    Makefile
	@# Bundle directory already created... now just sign it:
	exit 1 ; # need to sign app bundle

# Linux binary target (the native Love2D binary plus .love)
$(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux: $(LOVE_FILE) $(REQUIRED_ASSETS_LINUX_APP) Makefile
	@echo "Building Linux binary..."
	mkdir -p $(dir $@)
	# Extract the Love2D archive to a temporary location.
	unzip -q -o $(REQUIRED_ASSETS_LINUX_APP) -d $(BUILD_DIR)/linux_extracted
	# Assume the extracted Love binary is at $(BUILD_DIR)/linux_extracted/love;
	# copy it as the native binary.
	cp $(BUILD_DIR)/linux_extracted/love $@
	# Optionally, append the .love file or handle as per AppImage best practices.
	@[ -f $@ ] && echo "Created native Linux binary: $@"

ifeq ($(OS_TYPE),Windows)
# -- Package (Installer) Build Targets --
# Windows Installer via Inno Setup: Two ways.
# 1. Native Windows build: when running on Windows, invoke innosetup directly.
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe innosetup.iss
	@echo "Building Windows installer natively..."
	@$(if $(filter Windows,$(OS_TYPE)), \
	     innosetup "$(DIST_DIR)/innosetup.iss", \
	     echo "Error: Native Inno Setup installer build only available on Windows.")
	@[ -f $@ ] && echo "Created installer at: $@"
else
# 2. Windows Installer via Wine: when not on Windows, use Wine to run innosetup.
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME))Installer.exe: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_32.exe $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))_64.exe innosetup.iss Makefile
	@echo "Building Windows installer via Wine..."
	@$(if $(filter-out Windows,$(OS_TYPE)), \
	     wine innosetup "$(DIST_DIR)/innosetup.iss", \
	     echo "Error: Wine-based installer build not applicable on Windows.")
	@[ -f $@ ] && echo "Created installer via Wine at: $@"
endif

# macOS DMG Build Target
$(DIST_DIR)/$(call TO_TITLE_CASE,$(GAME_NAME)).dmg: $(MACOS_APP_BUNDLE) Makefile
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping macOS build: Not running on macOS."; exit 0; fi
	exit 1
	@echo "Packaging macOS App Bundle..."
	zip -9 -r $@ $(BUILD_DIR)/macos
	@echo "Created macOS package at $@"

# Linux Installer: Create an AppImage package.
$(DIST_DIR)/NotTetris-$(VERSION)-x86_64.AppImage: $(BUILD_DIR)/bin/$(call TO_TITLE_CASE,$(GAME_NAME))-linux $(BUILD_DIR)/icons/NotTetris2Icon_256.png Makefile
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
innosetup.iss: README.md LICENSE.txt $(BUILD_DIR)/icons/NotTetris2Icon_converted.ico NotTetris2Installer_artwork.bmp Makefile
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
	rm -rf $(GENERATED_FILES)

dist_clean: clean
	rm -rf $(DIST_DIR) $(VENDOR_DIR)

.PHONY: $(PSEUDO_TARGETS) clean

$(EVAL_PSEUDO_TARGETS_RULE)
