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
ASSERT_PSEUDO_TARGETS = $(if $(strip $(filter-out $(PSEUDO_TARGETS),$(1))),$(error $(filter-out $(1),$(PSEUDO_TARGETS)) is/are not in $$(PSEUDO_TARGETS). Please add them.),)

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

# @brief Generates functions to convert strings to snake_case and all uppercase.
#
# Defines two convenient user-level string transformation macros:
#   - TO_SNAKE_CASE: Converts an input string into snake_case.
#   - TO_ALL_CAPS:   Converts an input string into ALL_CAPS format.
#
# Each of these macros accepts a single string argument and returns the formatted string.
#
# @param None
# @return Two variables (user-defined functions) are defined:
#         - TO_SNAKE_CASE: function(string) → snake_case_string
#         - TO_ALL_CAPS:   function(string) → ALL_CAPS_STRING
#
# @note Internally, both macros are dynamically generated using an advanced meta-programming 
#       process. This process involves iterating over definitions ("function_name:case_transformer") 
#       and constructing each macro through a sequence of nested substitutions.
#
#       Temporary marker tokens are used during transformation to reliably detect word boundaries. 
#       These internal markers are:
#         - |1: Represents a literal vertical bar (|) character.
#         - |2 and |3: Inserted before and after uppercase letters, respectively.
#         - |4 and |5: Inserted before and after lowercase letters, respectively.
#         - |6: Inserted before an uppercase character immediately followed by a lowercase character,
#               aiding in detecting certain word boundaries.
#
#       Specifically, word boundaries for inserting underscores (in snake_case) or maintaining separation 
#       (in all_caps) are detected by two composite marker sequences:
#         1. "|5|2": Identifies a lowercase-to-uppercase transition as a word boundary.
#         2. "|3|2|6": Identifies the boundary between two uppercase letters when the second uppercase 
#                      letter is followed by a lowercase letter.
#
#       These markers and composite sequences are entirely internal implementation details. 
#       They ensure accurate and maintainable word boundary detection, simplifying the public 
#       interface exposed to macro callers.
$(foreach blob,TO_SNAKE_CASE:TO_LOWER TO_ALL_CAPS:TO_UPPER,$(call \
	DEFINE_VAR,$\
	$(call GET_FIELD_FROM_BLOBS,1,$(blob)),$\
	$(DOLLARS)$(OPEN_PAREN)call $(call GET_FIELD_FROM_BLOBS,2,$(blob))$(COMMA)$\
	$(DOLLARS)$(OPEN_PAREN)subst \
		|1$(COMMA)$\
		|$(COMMA)$\
		$(subst \
			$(COMMA)$(SPACE)$(DOLLARS),$\
			$(COMMA)$(DOLLARS),$\
			$(foreach \
				marker,$\
				2 3 4 5 6,$\
				$(DOLLARS)$(OPEN_PAREN)subst \
					|$(marker)$(COMMA)$\
					$(COMMA)$\
			)$\
		)$\
	$(DOLLARS)$(OPEN_PAREN)subst \
		|5|2$(COMMA)$\
		_$(COMMA)$\
	$(DOLLARS)$(OPEN_PAREN)subst \
		|3|2|6$(COMMA)$\
		_$(COMMA)$\
		$(subst \
			$(COMMA)$(SPACE)$(DOLLARS),$\
			$(COMMA)$(DOLLARS),$\
			$(foreach \
				pair,$\
				$(UC_LC_LETTER_PAIRS),$\
				$(DOLLARS)$(OPEN_PAREN)subst \
					$(call \
						GET_FIELD_FROM_BLOBS,$\
						1,$\
						$(pair)$\
					)|3|4$(COMMA)$\
					|6$(call \
						GET_FIELD_FROM_BLOBS,$\
						1,$\
						$(pair)$\
					)|3|4$(COMMA)$\
			)$\
		)$(subst \
			$(COMMA)$(SPACE)$(DOLLARS),$\
			$(COMMA)$(DOLLARS),$\
			$(foreach \
				pair,$\
				$(UC_LC_LETTER_PAIRS),$\
				$(DOLLARS)$(OPEN_PAREN)subst \
					$(call \
						GET_FIELD_FROM_BLOBS,$\
						2,$\
						$(pair)$\
					)$(COMMA)$\
					|4$(call \
						GET_FIELD_FROM_BLOBS,$\
						2,$\
						$(pair)$\
					)|5$(COMMA)$\
			)$\
		)$(subst \
			$(COMMA)$(SPACE)$(DOLLARS),$\
			$(COMMA)$(DOLLARS),$\
			$(foreach \
				pair,$\
				$(UC_LC_LETTER_PAIRS),$\
					$(DOLLARS)$(OPEN_PAREN)subst \
						$(call \
							GET_FIELD_FROM_BLOBS,$\
							1,$\
							$(pair)$\
						)$(COMMA)$\
						|2$(call \
							GET_FIELD_FROM_BLOBS,$\
							1,$\
							$(pair)$\
						)|3$(COMMA)$\
						)$\
			)$\
					$(DOLLARS)$(OPEN_PAREN)subst \
						|$(COMMA)$\
						|1$(COMMA)$\
						$(DOLLARS)$(OPEN_PAREN)subst \
							$(DOLLARS)(SPACE)$(COMMA)$\
							_$(COMMA)$\
							$(DOLLARS)(1)$\
						$(CLOSE_PAREN)$\
					$(CLOSE_PAREN)$\
		$(subst \
			$(SPACE),$\
			,$\
			$(foreach \
				pair,$\
				$(UC_LC_LETTER_PAIRS),$\
				$(CLOSE_PAREN)$\
			$(CLOSE_PAREN)$\
			$(CLOSE_PAREN)$\
			)$\
		$(subst \
			$(COMMA)$(SPACE)$(DOLLARS),$\
			$(COMMA)$(DOLLARS),$\
			$(foreach \
				marker,$\
				2 3 4 5 6,$\
				$(CLOSE_PAREN)$\
			)$\
		)$\
		)$(CLOSE_PAREN)$(CLOSE_PAREN)$(CLOSE_PAREN)$(CLOSE_PAREN),$\
	=$\
))

$(call ASSERT_EQ,$(DOLLARS)(call TO_SNAKE_CASE,TheQuick BROWNFox),the_quick_brown_fox)
$(call ASSERT_EQ,$(DOLLARS)(call TO_ALL_CAPS,jumps over_THELazyDog),JUMPS_OVER_THE_LAZY_DOG)

# @brief Converts an input string to lowercase words separated by spaces.
#
# This macro first converts the input string to snake_case and then replaces underscores
# with spaces, resulting in a lowercase, space-separated phrase.
#
# @param 1 Input string to convert.
# @return Lowercase words separated by spaces.
TO_LC_WORDS = $(subst _,$(SPACE),$(call TO_SNAKE_CASE,$(1)))

# @brief Converts an input string to uppercase words separated by spaces.
#
# This macro converts the input string to ALL_CAPS format and replaces underscores with spaces,
# yielding an uppercase, space-separated phrase.
#
# @param 1 Input string to convert.
# @return Uppercase words separated by spaces.
TO_UC_WORDS = $(subst _,$(SPACE),$(call TO_ALL_CAPS,$(1)))

$(call ASSERT_EQ,$(DOLLARS)(call TO_LC_WORDS,PeterPiper PICKED_aPeck),peter piper picked a peck)
$(call ASSERT_EQ,$(DOLLARS)(call TO_UC_WORDS,of pickeledPEPPERS),OF PICKELED PEPPERS)

# @brief [Internal] Converts an input string into a Camel_Snake_Case intermediate form.
#
# Internal helper macro for camel-case transformations. Not intended for direct use by callers.
#
# @param 1 Input string.
# @return String converted to Camel_Snake_Case (words capitalized, separated by underscores).
$(call \
	DEFINE_VAR,$\
	INTERNAL_TO_CAMEL_SNAKE_CASE,$\
	$(subst \
		$(COMMA)$(SPACE)$(DOLLARS),$\
		$(COMMA)$(DOLLARS),$\
		$(foreach \
			pair,$\
			$(UC_LC_LETTER_PAIRS),$\
			$(DOLLARS)$(OPEN_PAREN)subst _$(call \
				GET_FIELD_FROM_BLOBS,$\
				2,$\
				$(pair)$\
			)$(COMMA)$\
			_$(call \
				GET_FIELD_FROM_BLOBS,$\
				1,$\
				$(pair)$\
			)$(COMMA)$\
		)$\
	)$(DOLLARS)$(OPEN_PAREN)call TO_SNAKE_CASE$(COMMA)$(DOLLARS)$(OPEN_PAREN)1$(CLOSE_PAREN)$(CLOSE_PAREN)$(subst \
		$(SPACE),$\
		,$\
		$(foreach pair,$(UC_LC_LETTER_PAIRS),$(CLOSE_PAREN))$\
	),=)

$(call ASSERT_EQ,$(DOLLARS)(call INTERNAL_TO_CAMEL_SNAKE_CASE,PeterPiper PICKED_aPeck),peter_Piper_Picked_A_Peck)

# @brief Converts an input string into camelCase.
#
# This macro converts the input string into camelCase, removing all underscores and
# capitalizing each word except the first.
#
# @param 1 Input string to convert.
# @return camelCase formatted string.
TO_CAMEL_CASE = $(subst _,,$(call INTERNAL_TO_CAMEL_SNAKE_CASE,$(1)))

$(call ASSERT_EQ,$(DOLLARS)(call TO_CAMEL_CASE,PeterPiper PICKED_aPeck),peterPiperPickedAPeck)

# @brief [Internal] Converts an input string to Title_Snake_Case intermediate form.
#
# Internal helper macro used for title-case transformations. Not intended for direct use by callers.
#
# @param 1 Input string.
# @return String converted to Title_Snake_Case (words capitalized, separated by underscores).
$(call \
	DEFINE_VAR,$\
	INTERNAL_TO_TITLE_SNAKE_CASE,$\
	$(subst \
		$(COMMA)$(SPACE)$(DOLLARS),$\
		$(COMMA)$(DOLLARS),$\
		$(foreach \
			pair,$\
			$(UC_LC_LETTER_PAIRS),$\
			$(DOLLARS)$(OPEN_PAREN)patsubst $(call \
				GET_FIELD_FROM_BLOBS,$\
				2,$\
				$(pair)$\
			)%$(COMMA)$\
			$(call \
				GET_FIELD_FROM_BLOBS,$\
				1,$\
				$(pair)$\
			)%$(COMMA)$\
		)$\
	)$(DOLLARS)$(OPEN_PAREN)call INTERNAL_TO_CAMEL_SNAKE_CASE$(COMMA)$(DOLLARS)$(OPEN_PAREN)1$(CLOSE_PAREN)$(CLOSE_PAREN)$(subst \
		$(SPACE),$\
		,$\
		$(foreach pair,$(UC_LC_LETTER_PAIRS),$(CLOSE_PAREN))$\
	),=)

$(call ASSERT_EQ,$(DOLLARS)(call INTERNAL_TO_TITLE_SNAKE_CASE,PeterPiper PICKED_aPeck),Peter_Piper_Picked_A_Peck)

# @brief Converts an input string into TitleCase.
#
# This macro removes underscores and capitalizes every word, yielding a TitleCase formatted string.
#
# @param 1 Input string to convert.
# @return TitleCase formatted string.
TO_TITLE_CASE = $(subst _,,$(call INTERNAL_TO_TITLE_SNAKE_CASE,$(1)))

# @brief Converts an input string into Title Case with spaces.
#
# This macro converts the input string to Title Case, capitalizing every word and separating words with spaces.
#
# @param 1 Input string to convert.
# @return Title Case formatted string with words separated by spaces.
TO_TITLE_CASE_WORDS = $(subst _,$(SPACE),$(call INTERNAL_TO_TITLE_SNAKE_CASE,$(1)))

$(call ASSERT_EQ,$(DOLLARS)(call TO_TITLE_CASE,PeterPiper PICKED_aPeck),PeterPiperPickedAPeck)
$(call ASSERT_EQ,$(DOLLARS)(call TO_TITLE_CASE_WORDS,PeterPiper PICKED_aPeck),Peter Piper Picked A Peck)


# @brief Retrieves the system name using uname (or detects Windows).
#
# This macro obtains the underlying OS type using the `uname -s` command or checks for Windows via the `OS` environment variable.
#
# @param None
# @return OS system name (e.g., Darwin, Linux, Windows).
UNAME_S := $(shell \
	if [ "$$OS" = "Windows_NT" ] ; then \
		echo Windows ; \
	else \
		command -v uname > /dev/null && \
			uname -s ; \
	fi\
)

# @brief Determines a simplified OS type.
#
# OS_TYPE will contain one of four simplified OS identifiers: "Windows", "macOS", "Unix/Linux", or "Unknown".
#
# @param None
# @return Simplified operating system type identifier.
#         Value will be one of: "Windows", "macOS", "Unix/Linux", or "Unknown".
#
# @note Internally, this macro evaluates UNAME_S:
#       - "Darwin" → "macOS"
#       - Contains "MINGW", "MSYS", or "CYGWIN" → "Windows"
#       - Otherwise, if defined, → "Unix/Linux"
#       - If UNAME_S is undefined or empty → "Unknown"
OS_TYPE := $(if \
	$(filter \
		Darwin Windows,$\
		$(UNAME_S)$\
	),$\
	$(subst Darwin,macOS,$(UNAME_S)),$\
	$(if \
		$(strip \
			$(findstring MINGW,$(UNAME_S)) $(findstring MSYS,$(UNAME_S)) $(findstring CYGWIN,$(UNAME_S))$\
		),$\
		Windows,$\
		$(if $(UNAME_S),Unix/Linux,Unknown)$\
	)$\
)

