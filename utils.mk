BLANK :=
SPACE := $(BLANK) $(BLANK)
TAB := $(BLANK)	$(BLANK)
OPEN_PAREN := (
CLOSE_PAREN := )
OPEN_CURLEY := {
CLOSE_CURLEY := }
SNG_QUOTE := '
DBL_QUOTE := "
BACKSLASH := \$(BLANK)
COMMA := ,
DOLLARS := $$
HASH := \#

define NEWLINE


endef

SPECIAL_SHELL_CHARS := $(DOLLARS) $(BACKSLASH) ! ` " ' * ? [ ] ( ) { } < > | ; & $(HASH)

# @brief Reverse a list of words.
#
# This macro takes a space‐separated list and returns a new list whose items
# appear in reverse order. It does so by recursively removing the first word of
# the list and appending it to the result of reversing the remainder. This
# implementation is compatible with GNU Make 3.81.
#
# @param 1 A space‐separated list of words.
# @return The list in reverse order.
#
# @example
#   MYLIST = one two three
#   REVLIST = $(call REVERSE,$(MYLIST))
#   # REVLIST expands to "three two one"
REVERSE = $(strip $(if $1,$(call REVERSE,$(wordlist 2,$(words $1),$1)) $(firstword $1)))

# @brief Selects singular or plural form based on the number of words.
#
# This macro takes three arguments:
#   $(1) - A space‐separated string.
#   $(2) - The singular form (used when $(1) contains exactly one word).
#   $(3) - The plural form (used when $(1) contains zero or more than one word).
#
# @param 1 The input string whose word count is evaluated.
# @param 2 The singular form string.
# @param 3 The plural form string.
# @return The singular form if there is exactly one word in $(1); otherwise, the plural form.
SINGULAR_PLURAL = $(if $(filter 1,$(words $(1))),$(2),$(3))

# @brief Joins a list of words with a specified delimiter.
#
# This macro takes a space‐separated list (argument $(1)) and a delimiter (argument $(2))
# and returns a single string in which all words have been joined by the delimiter.
# Leading and trailing whitespace is removed prior to joining.
#
# @param 1 The space‐separated list of words to join.
# @param 2 The string delimiter to use between words.
# @return A single string with the words in $(1) joined by $(2).
SIMPLE_JOIN_LIST = $(subst \
	$(SPACE),$\
	$(2),$\
	$(strip $(1))$\
)

# @brief Joins a list of words into a grammatically formatted string.
#
# This macro concatenates the words in a space-separated list (argument $(1)) using different
# join delimiters depending on the list length:
#
#   - For an empty list, it returns the fallback value provided in $(4).
#   - For a single-word list, it returns that word.
#   - For a two-word list, it returns the two words joined by the delimiter in $(2).
#   - For lists with more than two words, it joins all but the last word using the delimiter in $(3),
#     then appends the final joining delimiter $(2) followed by the last word.
#
# This is intended to produce natural-sounding, English-style list formatting.
#
# @param 1 The input space-separated list of words.
# @param 2 The final delimiter to use between the penultimate and last item (e.g. " and ").
# @param 3 The delimiter to use between earlier items (e.g. ", ").
# @param 4 The fallback string to return if the list is empty.
#
# @return A grammatically formatted list string based on the number of input words.
#
# @example
#   $(call GRAMATICAL_JOIN_LIST,foo,$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none)
#     → foo
#
#   $(call GRAMATICAL_JOIN_LIST,foo bar,$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none)
#     → foo and bar
#
#   $(call GRAMATICAL_JOIN_LIST,foo bar baz,$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none)
#     → foo, bar and baz
#
#   $(call GRAMATICAL_JOIN_LIST,,$(SPACE)and$(SPACE),$(COMMA)$(SPACE),none)
#     → none
GRAMATICAL_JOIN_LIST = $(if \
	$(filter 0,$(words $(1))),$\
	$(4),$\
	$(if \
		$(filter 1,$(words $(1))),$\
		$(firstword $(1)),$\
		$(if \
			$(filter 2,$(words $(1))),$\
			$(firstword $(1)),$\
			$(call \
				SIMPLE_JOIN_LIST,$\
				$(call \
					REVERSE,$\
					$(wordlist \
						2,$\
						$(words $1),$\
						$(call \
							REVERSE,$\
							$(1)$\
						)$\
					)$\
				),$\
				$(3)$\
			)$\
		)$(2)$(lastword $(1))$\
	)$\
)

# @brief List of pseudo targets.
#
# Pseudo targets are modal boolean flags that alter the behavior of the build without
# directly building any files. The complete list of pseudo targets should be defined in the
# main Makefile. (In this file, we add the 'debug' flag for debugging purposes.)
PSEUDO_TARGETS := $(sort $(PSEUDO_TARGETS) debug)

# @brief Defines and evaluates Make rules to handle pseudo targets.
#
# This macro creates no-operation rules for all defined pseudo targets, allowing
# them to behave as boolean command-line flags without triggering unintended build
# actions. It ensures that each pseudo target either does nothing or redirects
# to the default goal if no other explicit targets are specified.
#
# To correctly enable pseudo-target behavior, you must:
#   1. Add all pseudo targets listed in $(PSEUDO_TARGETS) to your .PHONY declaration:
#        .PHONY: $(PSEUDO_TARGETS)
#   2. Expand EVAL_PSEUDO_TARGETS_RULE at the bottom of your Makefile simply by referencing it:
#        $(EVAL_PSEUDO_TARGETS_RULE)
#
# Failing to perform these two steps will result in pseudo targets not working as
# intended.
#
# @param None
# @return Evaluates rules for pseudo targets via $(eval).
#
# @note Internally, this macro defines each pseudo target as depending on the
#       Makefile's default goal if and only if no other explicit targets were
#       specified, thus preserving normal build behavior. The associated action
#       is explicitly defined as a no-op to prevent any unintended commands from
#       executing.
EVAL_PSEUDO_TARGETS_RULE = $(eval $(NEWLINE)$(PSEUDO_TARGETS):$(if $(strip $(filter-out $(PSEUDO_TARGETS),$(MAKECMDGOALS))),,$(SPACE)$(.DEFAULT_GOAL))$(NEWLINE)$(TAB)@\# no-op$(NEWLINE)$(NEWLINE))

# @brief Asserts that specified target(s) exist in the pseudo-targets list.
#
# This macro checks whether the given target(s) (passed as the first argument)
# are present in the global PSEUDO_TARGETS list. If any target is missing, it triggers a make error.
#
# @param 1 The target or list of targets to validate against PSEUDO_TARGETS.
ASSERT_PSEUDO_TARGETS = $(if $(strip $(filter-out $(PSEUDO_TARGETS),$(1))),$(error $(filter-out $(1),$(PSEUDO_TARGETS)) $(call SINGULAR_PLURAL,$(filter-out $(1),$(PSEUDO_TARGETS)),is,are) not in $$(PSEUDO_TARGETS). Please add them.),)

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
#
# @note The $(BLANK) variables expansions are included
#       to ensure that leading and trailing spaces are
#       properly included.
DEFINE_VAR = \
    $(if $\
        $(call HAS_PSEUDO_TARGET,debug),$\
        $(warning    $(1)$(if $(3),$(3),:=)$$(BLANK)$(2)$$(BLANK)),$\
    )$\
    $(eval $(NEWLINE)$(1)$(if $(3),$(3),:=)$$(BLANK)$(2)$$(BLANK)$(NEWLINE))

# @brief Test variable used to track function increments.
#
# This variable is used to verify that macros such as DEFINE_VAR and LAZY_DEFINE_VAR properly
# update and increment variable values. It serves as a test mechanism to ensure the correctness
# of variable assignments during debugging.
TEST_FN_INCREMENT = $(words $(TEST_FN_INCREMENT__INTERNAL_ACC))$(call DEFINE_VAR,TEST_FN_INCREMENT__INTERNAL_ACC,X,+=)

# @brief Escapes special characters to enable safe string comparison.
#
# This macro replaces potentially problematic characters in an input string
# with unique placeholder tokens so that two strings containing whitespace,
# dollar signs, or underscores can be compared reliably in Make conditionals.
#
# The following substitutions are performed, in order:
#   - `_`          (underscore)  → `_us_`
#   - `$(SPACE)`   (space)       → `_sp_`
#   - `$(DOLLARS)` (dollar)      → `_dl_`
#   - `$(TAB)`     (tab)         → `_tb_`
#   - `$(NEWLINE)` (newline)     → `_nl_`
#
# @param 1 The original string to escape.
# @return A transformed string with all `_, space, $, tab, newline` replaced
#         by their corresponding `_us_, _sp_, _dl_, _tb_, _nl_` tokens.
ESCAPE_CHARS_FOR_CMP = $(subst $(NEWLINE),_nl_,$(subst $(TAB),_tb_,$(subst $(DOLLARS),_dl_,$(subst $(SPACE),_sp_,$(subst _,_us_,$(1))))))

# @brief Asserts equality between an actual value and an expected value.
#
# This macro defines an assertion by comparing the actual value (provided as the first argument)
# to the expected value (second argument). If they do not match, it produces a make error,
# optionally including a custom error message.
#
# @param 1 The actual value or expression to test.
# @param 2 The expected value.
# @param 3 (Optional) A custom error message to display if the assertion fails.
ASSERT_EQ = \
    $(call DEFINE_VAR,ASSERT_EQ__INTERNAL_ACTUAL,$(1),    :=)$\
	$(call DEFINE_VAR,ASSERT_EQ__INTERNAL_EXPRESSION,$(subst $(DOLLARS),$(DOLLARS)$(DOLLARS),$(1)),:=)$\
    $(if $\
        $(call HAS_PSEUDO_TARGET,debug),$\
        $(warning Testing if '$(call ESCAPE_CHARS_FOR_CMP,$(ASSERT_EQ__INTERNAL_ACTUAL))' is equal to '$(call ESCAPE_CHARS_FOR_CMP,$(2))'),$\
    )$\
	$(eval $(NEWLINE)ifneq ($(call ESCAPE_CHARS_FOR_CMP,$(ASSERT_EQ__INTERNAL_ACTUAL)),$(call ESCAPE_CHARS_FOR_CMP,$(2)))$(NEWLINE)$\
	$(DOLLARS)(error Value of $(DOLLARS)(ASSERT_EQ__INTERNAL_EXPRESSION) ("$$(ASSERT_EQ__INTERNAL_ACTUAL)") expected to be "$(subst $$,$$$$,$(2))": $(if $(3),$(3),Assertion failed))$(NEWLINE)$\
	endif$(NEWLINE))

# First test TEST_FN_INCREMENT:
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),0)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),1)

# Now test DEFINE_VAR:
$(call DEFINE_VAR,TEST__DEFINE_VAR__1,$(DOLLARS)(TEST_FN_INCREMENT))
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),3)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__1),2)
$(call DEFINE_VAR,TEST__DEFINE_VAR__2,$(DOLLARS)(TEST_FN_INCREMENT),:=)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),5)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__2),4)
$(call DEFINE_VAR,TEST__DEFINE_VAR__3,$(DOLLARS)(TEST_FN_INCREMENT),=)
$(call ASSERT_EQ,$(DOLLARS)(TEST_FN_INCREMENT),6)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__3),7)
$(call ASSERT_EQ,$(DOLLARS)(TEST__DEFINE_VAR__3),8)

# Some funcs from above not yet tested:
$(call ASSERT_EQ,$(DOLLARS)(call REVERSE,a b  c d  e),e d c b a)

$(call ASSERT_EQ,$(DOLLARS)(call SINGULAR_PLURAL,,is,are),are)
$(call ASSERT_EQ,$(DOLLARS)(call SINGULAR_PLURAL,foo,is,are),is)
$(call ASSERT_EQ,$(DOLLARS)(call SINGULAR_PLURAL,foo bar baz,is,are),are)

$(call ASSERT_EQ,$(DOLLARS)(call SIMPLE_JOIN_LIST,foo bar baz bee boo,X),fooXbarXbazXbeeXboo)
$(call ASSERT_EQ,$(DOLLARS)(call SIMPLE_JOIN_LIST,,X),)
$(call ASSERT_EQ,$(DOLLARS)(call SIMPLE_JOIN_LIST,foo,X),foo)

$(call ASSERT_EQ,$(DOLLARS)(call GRAMATICAL_JOIN_LIST,,X,Y,Z),Z)
$(call ASSERT_EQ,$(DOLLARS)(call GRAMATICAL_JOIN_LIST,foo,X,Y,Z),foo)
$(call ASSERT_EQ,$(DOLLARS)(call GRAMATICAL_JOIN_LIST,foo bar,X,Y,Z),fooXbar)
$(call ASSERT_EQ,$(DOLLARS)(call GRAMATICAL_JOIN_LIST,foo bar baz bee boo,X,Y,Z),fooYbarYbazYbeeXboo)

# --- Quoting functions ---

# @brief Escapes single quotes inside a shell string.
#
# This macro takes an input string and escapes all single quotes `'`
# so that the result can be safely quoted in a shell single-quoted string.
#
# @param 1 The string to escape.
# @return The escaped string, ready to wrap in single quotes.
SINGLE_QUOTE_SH_INNER = $(subst $(SNG_QUOTE),$(SNG_QUOTE)$(BACKSLASH)$(SNG_QUOTE)$(SNG_QUOTE),$(1))

# @brief Escapes double quotes and backslashes inside a shell string.
#
# This macro takes an input string and escapes all problematic characters
# so that it can be safely used inside a double-quoted shell string.
#
# Escaped characters include:
# - `\` (backslash)
# - `"` (double quote)
# - ``` ` ``` (backtick)
# - `!` (exclamation mark)
# - `$` (dollar sign)
#
# @param 1 The string to escape.
# @return The escaped string, ready to wrap in double quotes.
DOUBLE_QUOTE_SH_INNER = \
    $(subst \
        !,$\
        $(BACKSLASH)!,$\
        $(subst \
            $(DBL_QUOTE),$\
            $(BACKSLASH)$(DBL_QUOTE),$\
            $(subst \
                `,$\
                $(BACKSLASH)`,$\
                $(subst \
                    $(DOLLARS),$\
                    $(BACKSLASH)$(DOLLARS),$\
                    $(subst \
                        $(BACKSLASH),$\
                        $(BACKSLASH)$(BACKSLASH),$\
                        $(1)$\
                    )$\
                )$\
            )$\
        )$\
    )

# @brief Wraps a string in single quotes for safe shell use.
#
# This macro escapes the string using SINGLE_QUOTE_SH_INNER,
# then wraps it in single quotes `'...'`.
#
# @param 1 The string to quote.
# @return A fully shell-safe single-quoted string.
SINGLE_QUOTE_SH = $(SNG_QUOTE)$(call SINGLE_QUOTE_SH_INNER,$(1))$(SNG_QUOTE)

# @brief Wraps a string in double quotes for safe shell use.
#
# This macro escapes the string using DOUBLE_QUOTE_SH_INNER,
# then wraps it in double quotes `"..."`.
#
# @param 1 The string to quote.
# @return A fully shell-safe double-quoted string.
DOUBLE_QUOTE_SH = $(DBL_QUOTE)$(call DOUBLE_QUOTE_SH_INNER,$(1))$(DBL_QUOTE)

# Example unit tests for quoting:
$(call \
	ASSERT_EQ,$\
	$$(call SINGLE_QUOTE_SH,$\
	    It$(SNG_QUOTE)s complicated$\
	),$\
	$(SNG_QUOTE)It$(SNG_QUOTE)$(BACKSLASH)$(SNG_QUOTE)$(SNG_QUOTE)s complicated$(SNG_QUOTE))
$(call \
	ASSERT_EQ,$\
	$$(call DOUBLE_QUOTE_SH,$\
	    Hello $(DBL_QUOTE)world$(DBL_QUOTE) \$$(DOLLARS)user$\
	),$\
	$(DBL_QUOTE)Hello $(BACKSLASH)$(DBL_QUOTE)world$(BACKSLASH)$(DBL_QUOTE) \\\$$user$(DBL_QUOTE))


# @brief Prefix used for suppressing normal Make echo output.
#
# This macro is used when defining Make recipes:
# - If the 'debug' pseudo target is active, echo commands normally.
# - Otherwise, suppress output unless the command fails.
#
# @return `@` if quiet, empty otherwise.
QUIET_LINE = $(if $(call HAS_PSEUDO_TARGET,debug),,@)

# @brief Determines whether Make was invoked in silent mode.
#
# If `s` is present in $(MAKEFLAGS), then Make is running in silent mode.
# This is used to decide whether to explicitly echo commands.
#
# @return Non-empty if silent mode is active, empty otherwise.
SILENT_MODE := $(findstring s,$(MAKEFLAGS))

# @brief Echoes a shell command to stderr before executing it.
#
# In normal Make mode (non-silent), this macro:
#  - Quotes the command safely using SINGLE_QUOTE_SH
#  - Echoes the quoted command to stderr
#  - Then executes the command.
#
# In silent mode (`make -s`), it simply executes the command without echoing.
#
# @param 1 The shell command to run.
# @return The command to execute.
ECHO_THEN_EXECUTE = $(if $(SILENT_MODE),,echo $(call SINGLE_QUOTE_SH,$(1)) >&2 ;) $(1)

# @brief Emits a Makefile recipe line that ensures a directory exists.
#
# This macro generates a shell recipe line that checks whether a directory
# exists. If the directory is missing, it echoes the mkdir command (unless
# in silent mode) and then creates the directory using `mkdir -p`.
#
# The check and creation are both safely quoted to handle directory paths
# that may contain spaces or special characters.
#
# The `QUIET_LINE` macro is used to optionally suppress normal output,
# and `ECHO_THEN_EXECUTE` is used to provide visible feedback if Make is not silent.
#
# @param 1 The directory path to ensure exists.
#
# @return A recipe line suitable for use directly in a Makefile rule body.
#
# @example
#   $(RECIPE_LINE_CREATE_DIR_IF_MISSING,build/icons)
#   # Expands to something like:
#   #   [ -d "build/icons" ] || ( echo 'mkdir -p build/icons' >&2 ; mkdir -p 'build/icons' )
RECIPE_LINE_CREATE_DIR_IF_MISSING = $(QUIET_LINE)[ -d $(call DOUBLE_QUOTE_SH,$(1)) ] || ( $(call ECHO_THEN_EXECUTE,mkdir -p $(call SINGLE_QUOTE_SH,$(1))) )

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

# @brief Filters a list of blobs by matching a specific field.
#
# This macro iterates over a list of blobs (each blob being a string with fields
# separated by colons) and returns only those blobs for which the field specified by
# the first parameter matches the expected value (second parameter).
#
# @param 1 The field number (1-indexed) to be checked in each blob.
# @param 2 The expected value for that field.
# @param 3 A space-separated list of blobs, where each blob is a colon-delimited string.
# @return A space-separated list of blobs whose field number $(1) equals the value $(2).
#
# @example
#   $(call GET_BLOBS_MATCHING_FIELD,2,b,a:b:c d e:f:g:h i:b:k:l:m n:b)
#   // Returns: a:b:c   i:b:k:l:m n:b
GET_BLOBS_MATCHING_FIELD = $(foreach blob,$(3),$(if $(filter $(2),$(word $(1),$(subst :,$(SPACE),$(blob)))),$(blob),))

$(call ASSERT_EQ,$(DOLLARS)(call GET_BLOBS_MATCHING_FIELD,2,b,a:b:c d e:f:g:h i:b:k:l:m n:b),a:b:c   i:b:k:l:m n:b)

# @brief Replaces literal $$, space, tab, and newline with symbolic placeholders
#
# @param 1 The input string to escape.
# @return A string with the following substitutions *in order* (outermost to innermost):
#     $         -> $(DOLLARS)
#     <space>   -> $(SPACE)
#     <tab>     -> $(TAB)
#     <newline> -> $(NEWLINE)
ESCAPE_WHITESPACE = $\
    $(subst \
        $(NEWLINE),$\
        $$(NEWLINE),$\
        $(subst \
            $(TAB),$\
            $$(TAB),$\
            $(subst \
                $(SPACE),$\
                $$(SPACE),$\
                $(subst \
                    $$,$\
                    $$(DOLLARS),$\
                    $(1)$\
                )$\
            )$\
        )$\
    )

# @brief Reverses ESCAPE_WHITESPACE placeholders back to literal characters.
#
# Recognizes placeholders and the double-dollar literal:
#   $$            -> $
#   $(DOLLARS)    -> $
#   $(SPACE)      -> <space>
#   $(TAB)        -> <tab>
#   $(NEWLINE)    -> <newline>
UNESCAPE_WHITESPACE = $\
    $(subst \
        $$(DOLLARS),$\
        $(DOLLARS),$\
        $(subst \
            $$(SPACE),$\
            $(SPACE),$\
            $(subst \
                $$(TAB),$\
                $(TAB),$\
                $(subst \
                    $$(NEWLINE),$\
                    $(NEWLINE),$\
                    $(subst \
                        $$$$,$\
                        $$(DOLLARS),$\
                        $(1)$\
                    )$\
                )$\
            )$\
        )$\
    )

$(call ASSERT_EQ,$\
  $$(call ESCAPE_WHITESPACE,hello world),$\
  hello$$(SPACE)world$\
)
$(call ASSERT_EQ,$\
  $$(call UNESCAPE_WHITESPACE,hello$$(SPACE)world),$\
  hello world$\
)
$(call ASSERT_EQ,$\
  $$(call ESCAPE_WHITESPACE,all$$(SPACE)sorts$$(TAB)of$$(SPACE)$$(NEWLINE)$$(DOLLARS)whitespace),$\
  all$$(SPACE)sorts$$(TAB)of$$(SPACE)$$(NEWLINE)$$(DOLLARS)whitespace$\
)
$(call ASSERT_EQ,$\
  $$(call UNESCAPE_WHITESPACE,all$$$$(SPACE)sorts$$$$(TAB)of$$$$(SPACE)$$$$(NEWLINE)$$$$(DOLLARS)whitespace$$$$),$\
  all$(SPACE)sorts$(TAB)of$(SPACE)$(NEWLINE)$(DOLLARS)whitespace$(DOLLARS)$\
)

# @brief Conditionally double-quotes a shell string if and only if needed.
#
# Quotes the input via DOUBLE_QUOTE_SH when **any** of the following are true:
#   - The string is empty
#   - The string contains whitespace (space, tab, or newline)
#   - The string contains any shell-special character:
#       $, \, !, `, ", ', *, ?, [ ], ( ), { }, < >, |, ;, &, #
#
# Otherwise, returns the string unchanged.
#
# Internally this relies on ESCAPE_WHITESPACE to turn whitespace
# into placeholders like '$(SPACE)', which are themselves detected
# alongside real special characters via SPECIAL_SHELL_CHARS.
#
# @param 1  The input string to test.
# @return    The original string, or the result of DOUBLE_QUOTE_SH($(1))
#            if one of the above conditions is met.
#
# @see ESCAPE_WHITESPACE, SPECIAL_SHELL_CHARS, DOUBLE_QUOTE_SH
CONDITIONAL_QUOTE_SH = $(if \
	$(or \
		$(filter StartEnd,Start$(call ESCAPE_WHITESPACE,$(1))End),$\
		$(strip \
			$(foreach \
				char,$\
				$(SPECIAL_SHELL_CHARS),$\
				$(findstring $(char),$(call ESCAPE_WHITESPACE,$(1)))$\
			)$\
		)$\
	),$\
	$(call DOUBLE_QUOTE_SH,$(1)),$\
	$(1)$\
)

$(call ASSERT_EQ,$\
	$$(call CONDITIONAL_QUOTE_SH,),$\
	""$\
)

$(call ASSERT_EQ,$\
	$$(call CONDITIONAL_QUOTE_SH,path/to/a/file.txt),$\
	path/to/a/file.txt$\
)

$(call ASSERT_EQ,$\
	$$(call CONDITIONAL_QUOTE_SH,path/to/a/wild*card.txt),$\
	"path/to/a/wild*card.txt"$\
)

$(call ASSERT_EQ,$\
	$$(call CONDITIONAL_QUOTE_SH,a[5]),$\
	"a[5]"$\
)


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
POSIX_TYPE := $(if \
	$(filter \
		Darwin FreeBSD OpenBSD NetBSD,$\
		$(UNAME_S)$\
	),$\
	BSD,$\
	SysV$\
)

GET_FILE_PERMISSIONS_OCTAL = $(if $(filter BSD,$(POSIX_TYPE)),stat -f '%Lp',stat -c '%a')

# @brief Finds the first available tool from a list of supported command names.
#
# This macro checks a space-separated list of tool names and returns the name of the
# first tool that exists in the user’s environment. It performs the check by invoking
# a shell command for each tool:
#
#   - If a tool is prefixed with "windows:" and the build is not running on Windows,
#     it uses Wine to run the Windows native command via:
#         wine cmd /c "where <tool>"
#   - If the build is running on Windows, it uses the native Windows "where" command.
#   - Otherwise (on non-Windows systems without the "windows:" prefix), it uses:
#         command -v <tool>
#
# If the check fails for a tool, the macro echoes that tool’s name (with any "windows:" 
# prefix removed). The resulting output is a space-separated list of the missing tools.
#
# @param 1 A space-separated list of tool names to check, in order of preference.
#           (Note: The "windows:" prefix is supported but only triggers special handling 
#           as described above.)
# @return The name of the first available tool, or an empty string if none are found.
#
# @example
#   SEARCH_TOOL := $(call FIND_FIRST_TOOL,windows:innosetup git curl)
#   # On a non-Windows system, this will check for Innosetup using:
#   #   wine cmd /c "where innosetup"
#   # and for git and curl using "command -v". The result will be the first tool found.
#
# @note The check is performed with a $(shell ...) call that assembles a series of
#       fallback commands separated by semicolons (which serve only as command separators,
#       not as literal output). On every macro expansion, these commands are re-evaluated,
#       so the result is not automatically memoized.
#
# @see SIMPLE_JOIN_LIST for how the fallback shell expressions are constructed.
FIND_FIRST_TOOL = $(strip $(shell \
	$(subst \
		$(DOLLARS)(SPACE),$\
		$(SPACE),$\
		$(call \
			SIMPLE_JOIN_LIST,$\
			$(foreach \
				tool,$\
				$(1),$\
				($(DOLLARS)(SPACE)$(if \
				    $(and \
				        $(filter windows:%,$(tool)),$\
				        $(filter-out Windows,$(OS_TYPE))$\
				    ),$\
				    wine$(DOLLARS)(SPACE)cmd$(DOLLARS)(SPACE)/c$(DOLLARS)(SPACE)"where$(DOLLARS)(SPACE)\"$(patsubst windows:%,%,$(tool))\"",$\
				    $(if \
				        $(filter Windows,$(OS_TYPE)),$\
				        where,$\
				        command$(DOLLARS)(SPACE)-v$\
				    )$(DOLLARS)(SPACE)$(patsubst windows:%,%,$(tool))$\
				)>/dev/null$(DOLLARS)(SPACE)&&$\
					$(DOLLARS)(SPACE)echo$(DOLLARS)(SPACE)"$(patsubst windows:%,%,$(tool))"$(DOLLARS)(SPACE))$\
			), || $\
		)$\
	)$\
))

# @brief Identifies the missing tools from a list of supported command names.
#
# This macro checks a space-separated list of tool names, returning a list of tools
# that are not available in the user’s environment. For each tool in the input:
#
#   - If the tool is specified with a "windows:" prefix (e.g. "windows:innosetup") and 
#     the build is not running on Windows, it uses Wine to execute:
#         wine cmd /c "where <tool>"
#   - If the build is running on Windows, it uses the native Windows command:
#         where <tool>
#   - Otherwise (on non-Windows systems), it uses the POSIX command:
#         command -v <tool>
#
# For each tool, if the check fails (i.e. no executable is found), the tool's name
# (with any "windows:" prefix stripped) is echoed. The result is a space-separated
# list of the missing tools.
#
# @param 1 A space-separated list of tool names to check, in order of preference.
#           Tools that require Windows lookup may be prefixed with "windows:".
# @return A space-separated list of missing tools, or an empty string if all are found.
#
# @example
#   MISSING_TOOLS := $(call FIND_MISSING_TOOLS,windows:innosetup git curl)
#   # On a non-Windows system using Wine, this will check for innosetup via:
#   #   wine cmd /c "where innosetup"
#   # and for git and curl using "command -v". If, say, git is missing, MISSING_TOOLS
#   # will include "git" in the resulting string.
#
# @note The macro leverages a combination of shell commands and conditional logic.
#       It uses a substitution function (SIMPLE_JOIN_LIST) to join the fallback shell
#       expressions separated by semicolons. Each expression attempts to check for the tool's
#       presence and echoes the tool's name if it is missing. All output is then stripped of
#       extraneous whitespace.
FIND_MISSING_TOOLS = $(strip $(shell \
	$(subst \
		$(DOLLARS)(SPACE),$\
		$(SPACE),$\
		$(call \
			SIMPLE_JOIN_LIST,$\
			$(foreach \
				tool,$\
				$(1),$\
				($(DOLLARS)(SPACE)$(if \
				    $(and \
				        $(filter windows:%,$(tool)),$\
				        $(filter-out Windows,$(OS_TYPE))$\
				    ),$\
				    wine$(DOLLARS)(SPACE)cmd$(DOLLARS)(SPACE)/c$(DOLLARS)(SPACE)"where$(DOLLARS)(SPACE)\"$(patsubst windows:%,%,$(tool))\"",$\
				    $(if \
				        $(filter Windows,$(OS_TYPE)),$\
				        where,$\
				        command$(DOLLARS)(SPACE)-v$\
				    )$(DOLLARS)(SPACE)$(patsubst windows:%,%,$(tool))$\
				)>/dev/null$(DOLLARS)(SPACE)||$\
					$(DOLLARS)(SPACE)echo$(DOLLARS)(SPACE)"$(patsubst windows:%,%,$(tool))"$(DOLLARS)(SPACE))$\
			), ; $\
		)$\
	)$\
))
