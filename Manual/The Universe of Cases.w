The Universe of Cases.

How to specify what test cases exist for a project.

@h The intest file.
Each project tested by Intest needs to provide a file which says what
test cases exist and how to test them. This range of test cases is called
the "universe", and may contain thousands of possible tests, though Intest
is likely to act on only a few in any given run.

As previously noted, Intest needs a recipe file in order to run in any
useful fashion; by default, Intest expects to find this file at
= (text)
	PROJECT/Tests/PROJECT.intest
=
where |PROJECT| is the name of the tested project's home directory. But
with the |-using| switch at the command line, an alternative file can be
used somewhere else.

(Note that if Intest is being used in its simplified mode for testing Inform
extensions or kits, then there is no need to write an intest file or to
write recipes, so that this section can be ignored. But if you're curious,
it does this by running the generic file |inform7/Internal/Delia/extension.intest|,
a generic intest file which can be used with any directory extension or kit.)

@ The intest file is a UTF-8 encoded text file. It is a list of commands
which, for the most part, tell Intest where to find test cases, and then
definitions of recipes, which Intest can then use to test them.

Here is a typical simple recipe file. It begins with a command, telling Intest
the location of a directory of test cases which will have type |case|, and
then gives a single recipe, which Intest will use on whatever cases it
discovered in that directory.

= (text as Delia)
! This is my first try at testing the launcher program

-cases 'inform7/kinds-test/Tests/Test Cases'

-recipe
	set: $SOURCE = $PATH/$CASE.txt
	set: $A = $PATH/$CASE--A.txt
	set: $I = $PATH/$CASE--I.txt

	step: launcher $SOURCE >$A 2>&1
	or: 'launcher produced error messages' $A

	show: $A

	exists: $I
	or: 'passed without errors but no blessed output existed'

	match text: $A $I
	or: 'produced incorrect output'

-end
=

The details of a recipe (written between |-recipe| and |-end| above) are
in a special language called Delia, which is described in //Writing Intest Recipes//.
Otherwise, each line in this file is a command, and each command begins
with a dash |-|, except that blank lines are ignored. So are comment lines,
beginning with exclamation marks |!|.

@h Names of test cases.
Each test has a name, which has to be not too long and can contain only
certain characters (see below for details). A test may also have a title,
which can be different and longer. For example, a test might have the name
|DanDaresSpaceship| but the title "Dan Dare's Spaceship". Titles are not
very important to Intest, but names are.

Names typically come from the filenames of the files in which tests are
written. In the above example:
= (text as Delia)
-cases 'inform7/kinds-test/Tests/Test Cases'
=
if the directory given contained three files, |numerical.txt|, |text.txt|
and |lists.txt|, then the universe would consist of three tests with
the names |numerical|, |text| and |lists|.

There are a number of restrictions on test names:

(a) They are case-sensitive, so "Frogs" is different from "frogs". This
is true even if your file system is case-insensitive, as it probably is.
Your computer may regard |Frogs.txt| and |frogs.txt| as the same file,
but to Intest those names would refer to different cases. It follows
that you can't practicably have two case names which are the same except
for casing.

(b) The names |all|, |examples|, |extensions|, |problems| and |cases|
are reserved for Intest wildcards, and can't be used.

(c) A name cannot begin with a dash |-|, a caret |^|, a question mark |?|,
an exclamation mark |!|, an open bracket |(|, a square bracket |[|,
a full stop |.|, an underscore |_|, or a digit. It's probably best to
start with a letter.

(d) A name cannot consist only of digits and cannot be just a single letter.

(e) A name cannot contain a colon or a slash, forwards or backwards, and
must contain only filename-safe characters. It can contain white space, but
your life will be easier if it doesn't. Similarly, best to avoid accented
letters or emoji.

(f) A name cannot contain a double dash |--|.

@ The reason that names cannot contain double dashes is that many tests need
associated files in order to work. A typical arrangement is that the test
|DanDaresSpaceship| might produce the "actual" output |DanDaresSpaceship--A.txt|,
which needs to be stored somewhere, and then this needs to be compared with
an "ideal" or "blessed" version, kept in |DanDaresSpaceship--I.txt|.

Because these filenames have double dashes in them, Intest does not interpret
them as being tests in their own right: when scanning a directory for test
cases, it ignores them.

@h Types of test case.
There are four of these, though two are used only for testing Inform 7,
and can be ignored by everybody else. The general ones are:

(a) "case" -- where the expectation is that the program being tested will
accept this test case and not produce errors, and

(b) "problem" -- where the expectation is that the program will reject it
with error messages.

The Inform-specific ones are:

(c) "example" -- like a "case", but written into an Inform documentation file,
a format which takes a bit of decoding.

(d) "extension" -- like a "case", but one of the examples from an Inform extension
file, a format which takes even more decoding.

@ In addition, some tests are "annotated", meaning that details about them
are given at the top of the file in question. For example, here is an
unannotated test case file:
= (text)
	The internal text file of Tall Nettles is called "Nettles.txt".

	To begin:
		showme the file of Tall Nettles;
		let the line count be 1;
		repeat with T running through the file of Tall Nettles:
			say "[line count]  [T][line break]";
			increase the line count by 1.
=
And here is the same thing as an annotated file:
= (text)
	Test: Nettles
	Language: Basic
	For: Glulx
	IntOptions: -u -q -dataresourcetext '3:$PATH/Nettles--X.txt'

	The internal text file of Tall Nettles is called "Nettles.txt".

	To begin:
		showme the file of Tall Nettles;
		let the line count be 1;
		repeat with T running through the file of Tall Nettles:
			say "[line count]  [T][line break]";
			increase the line count by 1.
=
The difference, of course, is that the file begins with a run of header
lines, each of which sets one detail. These take the form "Key: Value",
where Key must be a single word. In a test case file, the first line must
be "Test: TITLE", that is, the key must be "Test" and the value must be the
title of the test. In an annotated problem case file, the same, but the
key must be "Problem" rather than "Test".

@ All Inform example files are annotated. There, the opening line is a little
more elaborate:
= (text)
	Example: ** Alpaca Farm 2
=
Here the opening line must have the key "Example" and the value is a row
of one to four asterisks, rating the example by difficulty, and then a title.
(This exactly follows the format used by the "indoc" tool for Inform:
examples come from Inform documentation.)

Similarly, all cases arising from extensions are "annotated".

@h Declaring the test cases.
A recipe file normally begins by declaring where all the cases live:

|-case F|, where |F| is a filename. Make this a test case of type "case".
Similarly for |-problem|, |-example|, |-extension|.

|-cases D|, where |D| is a directory name. Make every validly named text file
in this directory a test case of type "case". Similarly for |-problems|,
|-examples|, |-extensions|.

|-case| and |-problem| create unannotated cases and problems: to make
annotated ones, use |-annotated-case| and |-annotated-problem|. Similarly
for their plurals. Intest also recognises |-annotated-example| and |-annotated-extension|,
but since tests from examples or extensions are always annotated anyway, this
doesn't change matters.

As a final variation, note that Intest will ordinarily throw an error if
it cannot find cases at the places named. If you don't want that, use the
prefix "-possible". For example, |-possible-annotated-case|, |-possible-problems|.

@ Each case has a "recipe" assigned to it, a method for performing the test.
Often the same recipe will be assigned to every case, but not all always.

Recipes are named, with names put in square brackets. The default one is
called just |[Recipe]|, but any test case declaration can override that.
For example:
= (text as Delia)
	-cases [KindRecipe] 'inform7/kinds-test/Tests/Test Cases'
	-possible-annotated-case [SpecialHack] 'inform7/kinds-test/Tests/debugging.txt'
=
Here any cases found in |inform7/kinds-test/Tests/Test Cases| are given the
recipe |[KindRecipe]|, and if the file |inform7/kinds-test/Tests/debugging.txt|
is present, then it gets the recipe |[SpecialHack]|.

Whatever happens, the recipe(s) you need will have to be written: see below
for how to do that.

@ If, for whatever reason, you would like a given test not to be included
in Intest's wildcard names such as |all|, then you can write, say,
|-singular NAME|, where |NAME| is the test's name. For example, you might say:
= (text as Delia)
	-possible-annotated-case [SpecialHack] 'inform7/kinds-test/Tests/debugging.txt'
	-singular debugging
=
to mark the test |debugging|, which arises from the declaration, to be
excluded from |all|.

@ With a large project to test, you will probably have a lot of tests which,
though similar to each other, involve subtle variations in how they should be
carried out. One answer to that would be to have numerous recipes which are
all variations on a theme:
= (text as Delia)
	-cases [Reactor1] 'fusionreactor/Tests/HotCases'
	-cases [Reactor2] 'fusionreactor/Tests/ColdCases'
	-cases [Reactor3] 'fusionreactor/Tests/UnsafeCases'
=
But that is likely to result in having to write multiple, repetitive recipes.
A neater solution is to use "stipulations", like so:
= (text as Delia)
	-cases [Reactor:TEMP=Hot:STATUS=Safe] 'fusionreactor/Tests/HotCases'
	-cases [Reactor:TEMP=Cold:STATUS=Safe] 'fusionreactor/Tests/ColdCases'
	-cases [Reactor:TEMP=Hot:STATUS=Unsafe] 'fusionreactor/Tests/UnsafeCases'
=
Here the recipe |[Reactor]| will be used for all of these cases, but it will
start with the variables |$TEMP| and |$STATUS| set to values depending on
which bucket the tests came from. Note that those are local variables (i.e.,
different for each individual test), not global ones (the same for all).

@ It is also possible to set global variables which will apply to all recipes:
= (text as Delia)
	-set MAXTEMPERATURE 4000
=
This would create the variable |$$MAXTEMPERATURE|, which can be used by
every recipe. See below for more on Delia variables: the doubled dollar sign
means global, single means local.

@ Finally, test cases can be made available and globals can be set on a
platform-specific basis:
= (text as Delia)
	-if Windows -set EXESUFFIX '.exe'
	-if MacOS -annotated-cases [Main:EXTERNAL=inform7/Tests] 'inform7/Tests/Test Releases'
=
A line beginning |-if PLATFORM| will be obeyed only if |$$platform| matches the
value |PLATFORM|, case insensitively.

@h Test groups.
|-groups PATH| sets the groups directory to the given pathname. Any files
with the filename extension |.testgroup| are then taken to be lists of useful
test cases for some particular aspect of testing.

A typical test group file is just a list of lines, each of which specifies
some tests drawn from the Universe. Most often these are literal test names:
= (text)
	PM_RelationOtoVContradiction
	PM_BadRelationCondition
	Asym1to1
	ExoticCreation
	KOVEquivRelation
	OToORouteFinding
=
Blank lines are skipped, as are lines beginning with the comment character |!|.

More ambitiously, lines can give regular expressions for tests to match. This
group consists of the test |Soyuz| and anything whose name begins |Ariane-|.
= (text)
	Soyuz
	Ariane-%C+
=
By default, these are matched against either the name or the title of a case:
a successful match against either gets the test included in the group. But
we can say exactly what we want to match against by writing the line
|KEY includes PATTERN| or |KEY is PATTERN|:
= (text)
	Title includes %d%d
	Name is Pine2
	Language is Basic
	Description includes quick
=
This improbable group includes any test whose title has two consecutive digits
somewhere in it, or whose name is |Pine2|, or which sets the key |Language|
to the value |Basic| in its annotations (see below), or which sets the
key |Description| to something with the word "quick" in it.

It can sometimes be useful to see what tests this sort of thing actually implies:
= (text as ConsoleText)
	$ intest/Tangled/intest launcher -list :rockets
	Soyuz
	Ariane-5
	Ariane-6
=
which lists all tests in the universe for |launcher| which match one of the
lines from the |rockets.testgroup|.

@h Specifying the recipes.
A recipe file must also define at least one recipe. There are two ways
to do this:

|-recipe [NAME] FILE| says that the recipe |[NAME]| is defined in the given
text file.

|-recipe [NAME]| followed by a definition written in the intest file itself:
= (text as Delia)
	-recipe [NAME]
	    ...
	    ...
	-end
=
where the definition occupies the lines in between the |-recipe| line and the
|-end| line. (Those lines in between are not commands and don't start with
dashes.) If no |[NAME]| is given, the name is assumed to be just |[Recipe]|.

For how to write recipes, see//Writing Intest Recipes//.

@h The annotations in a test case.
As noted above, an annotated case opens with key-value pairs specifying
details about it: this run ends with a blank line, and then the actual
test material begins.

For example, this might be the block of annotations at the top of a test case:
= (text)
	Test: Nettles
	Language: Basic
	For: Glulx
	IntOptions: -u -q -dataresourcetext '3:$PATH/Nettles--X.txt'
=
What does Intest do with this information? The answer is not much. The opening
line is significant, in that it tells Intest that this file is indeed a
test case, and supplies a title for the test. (Without such an annotation,
the title would be set equal to the name.)

The other key-value pairs here are for the benefit of other programs. Examples,
which are intended as documentation for Inform, use some of these to say where
they should appear in the manual (or in an extension's documentation), how
they should be indexed, and so on:
= (text)
	Example: ** Alpha
	Location: Regular expression matching
	RecipeLocation: Testing
	Index: Testing command
	Description: Creating a beta-testing command that matches any line starting with punctuation.
	For: Z-Machine
=
So here, the keys |Location|, |RecipeLocation|, |Index|, and |Description| are
all for use by Indoc, and are not likely to matter to how the test is conducted.
There's actually a hidden key-value pair in this case: |Stars|, which is set
here to |**|.

What Intest does with all key-value pairs in these annotations, though, is to
pass them to the test recipe as variables. So, for example, when the example
|Alpha| is tested, the recipe would begin with the variable |$FOR| set to the
value |Z-Machine|. (Note that key names are fully capitalized when used as
variable names in this way.)

The practical effect is that individual test cases can specify variations
in how they should be tested, in a way which the test recipe can make use of.
When there are thousands of cases and some of them intentionally abuse the
program under test, quite a lot of flexibility is needed, and these annotations
make it much easier to write a recipe to handle every need.
