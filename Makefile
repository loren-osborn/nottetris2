# Basics:

BLANK :=
SPACE := $(BLANK) $(BLANK)
TAB := $(BLANK)	$(BLANK)
OPEN_PAREN := (
CLOSE_PAREN := )
COMMA := ,
DOLLARS := $$

define NEWLINE


endef

# @brief List of pseudo targets.
#
# Pseudo targets are targets that act purely like modal flags without any build steps or dependencies.
# They function as boolean command line options. The complete list of pseudo targets should be defined
# in the main makefile; here, we add 'debug' to support debugging functionality.
PSEUDO_TARGETS := $(sort $(PSEUDO_TARGETS) debug)

# @brief Asserts that specified target(s) exist in the pseudo-targets list.
# 
# This macro checks whether the given target(s) (passed as the first argument)
# are present in the global PSEUDO_TARGETS list. If any target is missing, it triggers a make error.
#
# @param 1 The target or list of targets to validate against PSEUDO_TARGETS.
ASSERT_PSEUDO_TARGETS = $(if $(strip $(filter-out $(1),$(PSEUDO_TARGETS))),$(error $(filter-out $(1),$(PSEUDO_TARGETS)) is/are not in $$(PSEUDO_TARGETS). Please add them.),)

# @brief Checks if a pseudo target is present among the make command goals.
# 
# This macro ensures that the specified target (provided as the first argument)
# is both defined in PSEUDO_TARGETS and included in the current make command goals.
#
# @param 1 The pseudo target to check.
# @return The target name if present; otherwise, it triggers an error.
HAS_PSEUDO_TARGET = $(call ASSERT_PSEUDO_TARGETS,$(1))$(filter $(1),$(MAKECMDGOALS))

# @brief Defines or updates a variable and optionally logs the assignment for debugging.
# 
# This macro conditionally defines a variable with a given value. If the 'debug' pseudo target is active,
# it issues a warning that logs the variable's name and the assignment details to help track variable assignments.
# The assignment operator defaults to ':=' if not specified.
#
# @param 1 The name of the variable to define.
# @param 2 The value to assign to the variable.
# @param 3 (Optional) The assignment operator (e.g., '=' or ':='); defaults to ':='.
DEFINE_VAR = $(if $(call HAS_PSEUDO_TARGET,debug),$(warning $(1)$(if $(3),$(3),:=)$(2)),)$(eval $(NEWLINE)$(1)$(if $(3),$(3),:=)$(2)$(NEWLINE))

# @brief Test variable used to track function increments.
#
# This variable is used to verify that macros such as DEFINE_VAR and LAZY_DEFINE_VAR properly
# update and increment variable values. It serves as a test mechanism to ensure the correctness
# of variable assignments during debugging.
TEST_FN_INCREMENT = $(words $(TEST_FN_INCREMENT__INTERNAL_ACC))$(call DEFINE_VAR,TEST_FN_INCREMENT__INTERNAL_ACC,X,+=)

# @brief Asserts equality between an actual value and an expected value.
#
# This macro defines an assertion by comparing the actual value (provided as the first argument)
# to the expected value (second argument). If they do not match, it produces a make error,
# optionally including a custom error message.
#
# @param 1 The actual value or expression to test.
# @param 2 The expected value.
# @param 3 (Optional) A custom error message to display if the assertion fails.
ASSERT_EQ = $(call DEFINE_VAR,ASSERT_EQ__INTERNAL_ACTUAL,$(1),:=)$\
	$(call DEFINE_VAR,ASSERT_EQ__INTERNAL_EXPRESSION,$(subst $(DOLLARS),$(DOLLARS)$(DOLLARS),$(1)),:=)$\
	$(eval $(NEWLINE)ifneq ($(subst _,_us_,$(subst $(SPACE),_sp_,$(ASSERT_EQ__INTERNAL_ACTUAL))),$(subst _,_us_,$(subst $(SPACE),_sp_,$(2))))$(NEWLINE)$\
	$(DOLLARS)(error Value of $(DOLLARS)(ASSERT_EQ__INTERNAL_EXPRESSION) ("$(ASSERT_EQ__INTERNAL_ACTUAL)") expected to be "$(2)": $(if $(3),$(3),Assertion failed))$(NEWLINE)$\
	endif$(NEWLINE))

# First test TEST_FN_INCREMENT:
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),0)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),1)

# Now test DEFINE_VAR:
$(call DEFINE_VAR,TEST__DEFINE_VAR__1, $(DOLLARS)(TEST_FN_INCREMENT))
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),3)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__1),2)
$(call DEFINE_VAR,TEST__DEFINE_VAR__2, $(DOLLARS)(TEST_FN_INCREMENT),:=)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),5)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__2),4)
$(call DEFINE_VAR,TEST__DEFINE_VAR__3, $(DOLLARS)(TEST_FN_INCREMENT),=)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),6)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__3),7)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__3),8)

# @brief Lazily defines a variable, deferring its evaluation.
#
# This macro delays the evaluation of a variable's value by wrapping a call to DEFINE_VAR.
# It is useful when the variable's value might change and should be computed at a later time.
#
# @param 1 The name of the variable to define.
# @param 2 The lazily evaluated value to assign to the variable.
# @param 3 (Optional) The assignment operator (e.g., '=' or ':='); defaults to ':='.
LAZY_DEFINE_VAR = $(call \
	DEFINE_VAR,$\
	$(1),$\
	$(DOLLARS)(call $\
		DEFINE_VAR$(COMMA)$\
		$(1)$(COMMA)$\
		$(subst \
			$(DOLLARS),$\
			$(DOLLARS)$(DOLLARS),$\
			$(subst \
				$(COMMA),$\
				$(DOLLARS)$(COMMA),$\
				$(2)$\
			)$\
		)$(COMMA)$\
		$(if $(3),$(3),:=)$\
	)$(DOLLARS)($(1)),=)

# Now test 
$(call LAZY_DEFINE_VAR,TEST__LAZY_DEFINE_VAR__1,$(DOLLARS)(TEST_FN_INCREMENT))
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),9)
$(call ASSERT_EQ,$(DOLLARS)(TEST__LAZY_DEFINE_VAR__1),10)
$(call ASSERT_EQ,$(DOLLARS)(TEST__LAZY_DEFINE_VAR__1),10)
$(call ASSERT_EQ,$(DOLLARS)(TEST__LAZY_DEFINE_VAR__1),10)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),11)

# @brief Extracts a specific field from each blob in a list.
# 
# This macro iterates over a list of blobs (each blob containing colon‑separated fields)
# and extracts the field specified by the first argument.
#
# @param 1 The field number to extract (1‑indexed).
# @param 2 A list of blobs where each blob is a string with fields separated by colons.
# @return A space‑separated list of the extracted fields.
GET_FIELD_FROM_BLOBS = $(foreach blob,$(2),$(word $(1),$(subst :,$(SPACE),$(blob))))

$(call ASSERT_EQ,$(DOLLARS)(call GET_FIELD_FROM_BLOBS,3,a:b:c d e:f:g:h i:j:k:l:m n:o),c  g k )

UC_LC_LETTER_PAIRS := A:a B:b C:c D:d E:e F:f G:g H:h I:i J:j K:k L:l M:m N:n O:o P:p Q:q R:r S:s T:t U:u V:v W:w X:x Y:y Z:z

# @brief Converts a given string to lowercase.
#
# This macro converts all uppercase characters in the input string (passed as the first argument)
# to their lowercase equivalents by applying a series of substitution rules.
#
# @param 1 The input string to convert to lowercase.
# @return The converted lowercase string.
$(call DEFINE_VAR,TO_LOWER,$(subst $(COMMA)$(SPACE)$(DOLLARS),$(COMMA)$(DOLLARS),$(foreach pair,$(UC_LC_LETTER_PAIRS),$(DOLLARS)$(OPEN_PAREN)subst $(call GET_FIELD_FROM_BLOBS,1,$(pair))$(COMMA)$(call GET_FIELD_FROM_BLOBS,2,$(pair))$(COMMA)))$(DOLLARS)(1)$(subst $(SPACE),,$(foreach pair,$(UC_LC_LETTER_PAIRS),$(CLOSE_PAREN))),=)
$(call ASSERT_EQ,$(DOLLARS)(call TO_LOWER,The Quick broWN FOX),the quick brown fox)

# @brief Converts a given string to uppercase.
#
# This macro converts all lowercase characters in the input string (passed as the first argument)
# to their uppercase equivalents by applying a series of substitution rules.
#
# @param 1 The input string to convert to uppercase.
# @return The converted uppercase string.
$(call DEFINE_VAR,TO_UPPER,$(subst $(COMMA)$(SPACE)$(DOLLARS),$(COMMA)$(DOLLARS),$(foreach pair,$(UC_LC_LETTER_PAIRS),$(DOLLARS)$(OPEN_PAREN)subst $(call GET_FIELD_FROM_BLOBS,2,$(pair))$(COMMA)$(call GET_FIELD_FROM_BLOBS,1,$(pair))$(COMMA)))$(DOLLARS)(1)$(subst $(SPACE),,$(foreach pair,$(UC_LC_LETTER_PAIRS),$(CLOSE_PAREN))),=)
$(call ASSERT_EQ,$(DOLLARS)(call TO_UPPER,jumps Over the lazy DOG),JUMPS OVER THE LAZY DOG)

$(error Stop here!)

ALL_LETTERS := A:a B:b C:c D:d E:e F:f G:g H:h I:i J:j K:k L:l M:m N:n O:o P:p Q:q R:r S:s T:t U:u V:v W:w X:x Y:y Z:z
TO_LOWER = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$(1)))))))))))))))))))))))))))
TO_UPPER = $(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$(1)))))))))))))))))))))))))))


UNAME_S := $(shell \
	if [ "$$OS" = "Windows_NT" ] ; then \
		echo Windows ; \
	else \
		command -v uname > /dev/null && \
			uname -s ; \
	fi\
)
# OS_TYPE will be one of: "Windows", "macOS", "Unix/Linux", or "Unknown"
OS_TYPE := $(if \
	$(filter \
		Darwin Windows,$\
		$(UNAME_S)$\
	),$\
	$(subst Darwin,macOS,$(UNAME_S)),$\
	$(if \
		$(strip \
			$(findstring MINGW,$(UNAME_S) $(findstring MSYS,$(UNAME_S) $(findstring CYGWIN,$(UNAME_S))$\
		),$\
		Windows,$\
		$(if $(UNAME_S),Unix/Linux,Unknown)$\
	)$\
)
ifeq($(OS_TYPE),Unknown)
	$(error I'm unable to detect your OS type! Aborting.)
endif



# Game Settings
GAME_NAME := Not Tetris 2
GAME_NAME_NOSPACES := $(subst $(SPACE),,$(GAME_NAME))
GAME_NAME_LOWER_NOSPACES := $(call TO_LOWER,$(GAME_NAME_NOSPACES))
VERSION := 2.1
IDENTIFIER := net.stabyourself.nottetris2
BUILD_DIR := build
DIST_DIR := dist
SOURCE_DIR := src
LOVE_FILE := $(BUILD_DIR)/$(GAME_NAME_LOWER_NOSPACES).love

# Required Tools (Generic)
REQUIRED_TOOLS_GENERIC := love zip

# Required Tools (macOS only)
REQUIRED_TOOLS_MAC := hdiutil codesign xcrun

# Combine lists conditionally
REQUIRED_TOOLS := $(REQUIRED_TOOLS_GENERIC)
ifneq ($(filter macOS,$(OS_TYPE)),)
  REQUIRED_TOOLS += $(REQUIRED_TOOLS_MAC)
endif

# Detect Package Manager
PACKAGE_MANAGER := $(shell which brew 2>/dev/null || which apt 2>/dev/null || which yum 2>/dev/null || which choco 2>/dev/null)
INSTALL_CMD := $(if $(findstring brew, $(PACKAGE_MANAGER)), brew install, \
              $(if $(findstring apt, $(PACKAGE_MANAGER)), sudo apt install -y, \
              $(if $(findstring yum, $(PACKAGE_MANAGER)), sudo yum install -y, \
              $(if $(findstring choco, $(PACKAGE_MANAGER)), choco install, \
              echo "No package manager found! Install dependencies manually." && exit 1))))

# Function to prompt for installation (as a single Bash string)
define prompt_for_install
	echo "The following required tools are missing: $$MISSING_TOOLS"; \
	read -p "Would you like to install them? (y/N) " choice; \
	if [ "$$choice" = "y" ]; then $(INSTALL_CMD) $$MISSING_TOOLS; else \
		echo "Warning: Some tools are missing! Build may fail."; \
	fi
endef

# Check for required tools
check-tools:
	@echo "Checking required tools..."
	@MISSING_TOOLS=""; \
	for tool in $(REQUIRED_TOOLS); do \
		if ! command -v $$tool >/dev/null; then \
			MISSING_TOOLS="$$MISSING_TOOLS $$tool"; \
		fi; \
	done; \
	if [ -n "$$MISSING_TOOLS" ]; then $(prompt_for_install); fi
	@echo "All required tools checked!"

# Build LÖVE Archive
$(LOVE_FILE): check-tools
	@echo "Creating LÖVE archive..."
	mkdir -p $(BUILD_DIR)
	cd $(SOURCE_DIR) && zip -9 -r ../$(LOVE_FILE) ./*
	@echo "LÖVE archive created at $(LOVE_FILE)"

# Windows Build
windows: $(LOVE_FILE)
	@echo "Building Windows Executable..."
	mkdir -p $(BUILD_DIR)/windows
	cat /usr/share/love/love.exe $(LOVE_FILE) > $(BUILD_DIR)/windows/$(GAME_NAME).exe
	cp -r /usr/share/love/*.dll $(BUILD_DIR)/windows/
	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-win.zip $(BUILD_DIR)/windows
	@echo "Windows Build Created: $(DIST_DIR)/$(GAME_NAME)-win.zip"

# Linux Build
linux: $(LOVE_FILE)
	@echo "Building Linux AppImage..."
	mkdir -p $(BUILD_DIR)/linux
	cp $(LOVE_FILE) $(BUILD_DIR)/linux/$(GAME_NAME).love
	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-linux.zip $(BUILD_DIR)/linux
	@echo "Linux Build Created: $(DIST_DIR)/$(GAME_NAME)-linux.zip"

# macOS Build
macos: $(LOVE_FILE)
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping macOS build: Not running on macOS."; exit 0; fi
	@echo "Building macOS App Bundle..."
	mkdir -p $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/{MacOS,Resources}
	cp $(LOVE_FILE) $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/MacOS/$(GAME_NAME)
	echo "APPL????" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/PkgInfo
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<plist version=\"1.0\">" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<dict>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<key>CFBundleIdentifier</key>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "<string>$(IDENTIFIER)</string>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "</dict>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	echo "</plist>" >> $(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Info.plist
	zip -9 -r $(DIST_DIR)/$(GAME_NAME)-macos.zip $(BUILD_DIR)/macos
	@echo "macOS Build Created: $(DIST_DIR)/$(GAME_NAME)-macos.zip"

# macOS Signing
sign-macos: macos
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping signing: Not running on macOS."; exit 0; fi
	@echo "Signing macOS App..."
	codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name (XXXXXXXXXX)" $(BUILD_DIR)/macos/$(GAME_NAME).app

# macOS Notarization (Placeholder)
notarize-macos: sign-macos
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping notarization: Not running on macOS."; exit 0; fi
	@echo "Notarizing macOS App (Requires Apple Developer Account)..."
	# Placeholder for Apple notarization command:
	# xcrun altool --notarize-app -f $(BUILD_DIR)/macos/$(GAME_NAME).zip --primary-bundle-id "$(IDENTIFIER)" --username "your@appleid.com" --password "@keychain:app-password"

# macOS DMG Creation
dmg: macos
	@if [ -z "$(filter macOS,$(OS_TYPE))" ]; then echo "Skipping DMG creation: Not running on macOS."; exit 0; fi
	@echo "Creating macOS DMG..."
	hdiutil create -fs HFS+ -volname "$(GAME_NAME)" -srcfolder $(BUILD_DIR)/macos -ov $(DIST_DIR)/$(GAME_NAME).dmg

# Clean Build Artifacts
clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)

.PHONY: check-tools windows linux macos sign-macos notarize-macos dmg clean

