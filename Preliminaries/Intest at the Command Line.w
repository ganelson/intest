Intest at the Command Line.

Intest is controlled with a flexible range of command-line instructions.

@h Specifying what to test.
Intest tests just one project at a time, and the first thing to do is
specify which. The general form is:

	|$ intest/Tangled/intest PROJECT COMMAND|

or, in case the |PROJECT| directory happens to begin with a hyphen and could
be confused with the name of a command-line switch,

	|$ intest/Tangled/intest -from PROJECT COMMAND|

|PROJECT| is optional if the |COMMAND| is simply |-help| or |-version|,
when of course no actual testing will happen.

The rest of this section is entirely about how to write a |COMMAND|.

@ Intest expects that |PROJECT| will be a directory, and that it will further
contain a subdirectory called |Tests|. But that is really the only assumption
it makes: there is no requirement for the project to be a web in the sense of
Inweb, or to be one of the Inform tools.

@h History and substitution.
For each different project |PROJECT|, Intest maintains a history of recent
commands in a file stored at:

	|PROJECT/Tests/intest-history.txt|

If Intest can't find this file, it silently continues; it will rewrite, or
create, this file when it exits, unless the |-no-history| setting is used.
(When Intest is being used less interactively -- for example, inside the
Inform user interface app -- this setting avoids clutter.)

The first thing Intest does with a |COMMAND| is to make substitutions.
A |COMMAND| consisting of just "?" lists the project's current history, like so:

	|$ intest/Tangled/intest inform7 ?|
	|?1. cases|
	|?2. Abolition|
	|?3. Beatles Sackcloth Gelato|
	|?4. problems|
	|1 = PM_ActivityOf; 2 = PM_AdjectiveIsValue|

(If there's no recorded history, output is empty.) What this means is that
there have been four previous commands, called |?1| to |?4|. There are also
two test cases recently found to be troublesome, called |1| and |2|. History
is maintained for the previous 20 commands.

Intest uses both of these notations to save typing. The command |?3|, for
example, abbreviates |Beatles Sackcloth Gelato|. Thus:

	|$ intest/Tangled/intest inform7 ?3|
	|Repeating: ?3. Beatles Sackcloth Gelato|
	|...|

is equivalent to typing:

	|$ intest/Tangled/intest inform7 Beatles Sackcloth Gelato|

except that it doesn't add a new line to the history file, since this is a repeat of an old command, not a new one.

Calling intest with an empty command repeats its most recent new command:

	|$ intest/Tangled/intest inform7|
	|Repeating: ?4. problems|
	|...|

Finally, intest automatically expands any command line arguments consisting 
only of positive decimal numbers into the names recorded in the history. Thus

	|$ intest/Tangled/intest inform7 1 2|
	|Expanded to: ?5. PM_ActivityOf PM_AdjectiveIsValue|
	|...|

@h Command line arguments.
At this point, then, the command no longer has any |?|, |?n| or |n| tokens
in it, because those have all been taken care of. What remains is a "raw
command". This takes the form:

	|OPTIONS -usimg USING -do DO|

|OPTIONS|, which can be nothing at all, sets overall switches such as
|-no-history|. See below. |-using| tells Intest where to find test cases;
that too is optional. |-do| tells Intest which test cases to run. If there
isn't a |-using| block, there's no need to say |-do|, so simply

	|OPTIONS DO|

will work. For example,

	|-no-history bigarrays badvariables|

would set the option |-no-history| and then perform a "do" on the two test
cases named.

@h The options.
Are as follows:

|-history| and |-no-history| turn the writing of command history on or off.

|-colours| and |-no-colours| turn on or off the use of red and green terminal
text to show deletions and insertions when displaying differences.

|-verbose| and |-no-verbose| turn on or off the echoing of shell commands to
the standard output. (Unlike make, Intest is by default silent.)

|-threads=N| tells Intest to use up to |N| independent threads, with one test
at a time running on each thread. Experience shows that setting |N| to be
the number of processor cores you have, doubling if you have hyperthreading,
gives the fastest performance. |-threads=1| makes Intest run in a single
thread, which may be necessary on some platforms.

|-purge| is an option used only when testing Inform 7; it's a convenience for
removing the many temporary files created in the course of testing.

@h Using.
Before it can do any testing, Intest has to discover the universe of possible
named test cases available, and work out which recipe to use with each.

It normally does that by reading a recipe file stored at:

	|PROJECT/Tests/PROJECT.intest|

This is because the default |-using| setting is

	|-using PROJECT/Tests/PROJECT.intest|

You can alternatively say |-using R| for any recipe file |R|, which need not
be in the project folder.

It is also possible, though seldom useful, to give your recipe instructions
at the command line and not in a recipe file at all. Newcomers to Intest
should simply skip the following discussion, but:

	|-using USE1 USE2 ... USEn|

can instead be a list of use commands, some of a single token, some of
two or more. These can be:

(a) |-if P|, where |P| is a platform name, such as "windows". Act on the
succeeding use commands only if the platform is |P|.

(b) |-endif|. Go back to always acting on use commands.

(c) |-set VAR VALUE|. Set the given variable to the given value. 

(d) |[NAME]|. Sets the test recipe to be used for the cases about to be
discovered. All recipe names are in square brackets; the default is just
|[Recipe]|.

(e) A choice of test case type: |-extension|, |-case|, |-problem|, |-map|
or |-example|. This indicates that the next run of tokens will be
filenames of individual test cases of that type.

(f) A pluralised choice of these: |-extensions|, |-cases|, |-problems|,
|-maps| or |-examples|. This indicates that the next run of tokens will be
pathnames of directories holding multiple test cases of that type.

(g) A filename or directory name. Look here for test cases of the current
type, and assign them the current recipe.

(Test types, and what it means to scan a directory for test cases, will be
gone into in the next section.)

@h Doing.
The "doing" part of an Intest command is usually a list of test cases to
be tried. For example,

	|alpha beta gamma|

is implicitly read as

	|-test alpha beta gamma|

since |-test| is understood if no other do command is given.

Any number of names can be supplied, each of which must be one of the
following:

(i) |all| means all known tests;
(ii) |examples|, |extensions|, |problems|, |cases|, |maps| each mean all
known tests of the given type of origin;
(iii) |A|, |B|, |C|, ..., mean "the example with this letter in the (first)
extension case";
(iv) |^1|, |^2|, |^3|, ..., mean "the 1st (2nd, 3rd, ...) test case known",
-- this is not to be confused with the |1|, |2|, |3|, ... notation used
to call back previously failed cases: typically |^1| will be the first
test case alphabetically;
(iv) and, of course, an explicit test case name refers to that test case.

(Test types will be gone into in the next section.)

@ But other do commands are also available:

|-catalogue|: List all the known test cases. For large projects this might
produce an enormous list, but |-using| can cut that down. To give an example
from Inform,

	|$ intest/Tangled/intest inform7 -using -extension 'inform7/Internal/Extensions/Emily Short/Locksmith.i7x' -do -catalogue|
	|Locksmith Example A = John Malkovich's Toilet|
	|Locksmith Example B = Tobacco|
	|Locksmith Example C = Rekeying|
	|Locksmith Example D = Watchtower|

Here the universe of possible tests is reduced to just those which are given
in the documentation for this specific Inform extension. The |-catalogue|
then gives a full list of those four.

|-find <text>|: List all the known test cases whose case names or story
titles match |<text>|. This can in fact be a regular expression, using
|[...]|, |%c| for any character (not |.|), |%C| for any non-white-space, |%d|
for a digit, and so on. For example:

	|$ intest/Tangled/intest inform7 -find %d%d%d%d|
	|Test cases matching '%d%d%d%d':|
	|Jamaica1688 = Jamaica 1688|
	|Mapped = 1691|
	|Royal = 1691|
	|Royal2 = 1691|
	|Royal3 = 1691|
	|SP = Space Patrol #57 - 1953-10-31 - Stranded on Jupiter!|
	|Stoppers = Trachypachidae Maturin 1803|

(The reason for the equals signs here, and in the above example too, is that
an individual test case can have both a "name" -- such as |Stoppers| -- and also
a "title" -- such as "Trachypachidae Maturin 1803". The name is derived from
its filename. The title will only exist for cases extracted from Inform
example or extension files, and then it's the title of the story making up
the test case.)

|-source <cases>|: Output the contents of the test cases. This sounds
as if it does no more than printing out their source files, but it's a
non-trivial operation for some Inform test cases (those occurring as examples
or in extensions).

|-script <cases>|: This is relevant only for testing Inform. Output the
script of player inputs to be used when running the story file produced
by compiling this test case; the script being drawn from the

	|Test me with "..."|

line inside the source, if one is present. If no script is there, this
produces empty output, but does not throw an error. For example:

	|$ intest -using -extension 'inform7/Internal/Extensions/Emily Short/Locksmith.i7x' -do -script C|

prints out the command script for Example C of Locksmith:

	|i|
	|x key|
	|unlock box|
	|i|
	|x key|

|-concordance <cases>|: Output a concordance table for comparing line numbers
between the source text extracted by Intest vs. the original file they came
from. This is a sequence of lines of the form:

	|1 +404|

which means "from line 1 of the extracted output onwards, you have to add
404 to get the corresponding line of the original from which it came". There can
be any number of such lines, including none at all (which means: the line
numbers match); e.g.

	|1 +404|
	|21 +409|

means add 404 to lines 1 to 20, then add 409 from then on, presumably because
5 lines have been skipped. The list is always of minimal length and any offsets
quoted are always positive, so |+0| or |+-7| can't occur.

|-bless <cases>|: Test and then, if the case is cursed, bless the transcript
as correct. (If the case is already blessed, nothing changes.)

|-rebless <cases>|: Test and then bless the transcript as correct, replacing
any existing blessed transcript: equivalent to |-curse| followed by |-bless|.

|-curse <cases>|: Delete the blessed transcript for these cases. (Alas,
there's no such thing as |-recurse|.)

|-show <cases>|: Run a test just as far as the first |show| step in its recipe,
and then print out the file specified. For most recipes, this prints out, say,
the console output generated by the program being tested.

|-show-i6 <cases>|: Run a test just as far as taking it through the I6 compiler stage, and show the console output from I6. (This is for Inform only.)

|-open <cases>|: Call the shell command |open| on the file(s) from which the source text of these case(s) are drawn. On MacOS, for example, this is equivalent to double-clicking them in the Finder, and likely means they will open in the default text editor.

|-diff <cases>|: Test and then, if a |match| step fails in its recipe, run
the shell command |diff| on the actual versus ideal versions of the output
being matched.

|-bbdiff <cases>|: Like |-diff|, but using the |bbdiff| tool instead. You will only have this if you're running the BBEdit text editor on MacOS.

@h Output redirection.
Do commands producing textual output, such as |-source|, normally send that to
the standard output stdout. (If you're using Intest in a |bash| or similar
shell on a Unix-based operating system, this means it can be piped to an
application or redirected to a file.) But you can also ask Intest itself to
redirect the output, since any action can optionally be followed by
|-to <filename>|.

This redirects output to the given file, which is created (and overwrites any
file already existing with that name). In a |-to| destination, any usage in
the filename of the text |[NAME]| expands to the name of the test case; any
usage of |[NUMBER]| expands to a unique integer, counting upwards from 1, for
each test case being applied to by this action. Thus, for example:

	|-source A B C D -to source_[NAME].txt|

might write four files, called, say,

	|source_Locksmith Example A.txt|
	|source_Locksmith Example B.txt|
	|source_Locksmith Example C.txt|
	|source_Locksmith Example D.txt|

Note that if you write multiple do commands, they can each have independent
|-to| destinations.

@h Reporting on test outcomes in the Inform app.
Two special do commands are provided for use of the Inform app only (well,
it's hard to think of anyone else who would need them). The idea here is that
after the Inform app has conducted a test, it asks intest to produce an HTML
page to describe the results of the test, passing over the information needed
to do this:

	|-report <case> <code> <problems-file> <skein-file>|

Here |<case>| is a single case, not a list, and |<code>| is one of:

(a) |i7|: meaning, failed i7, i.e., |ni| produced problem messages
(b) |i6|: meaning, failed to compile in i6
(c) |wrong|: meaning, the story file compiled and started, but the transcript didn't match its blessed version
(d) |right|: meaning, a success: story file compiled and started, and matched transcript

|<problems-file>| is the file generated by ni, in the event of either success or failure, which is usually stored in the project's |Build/Problems.html|.

|<skein-file>| is only looked at (potentially) in case (c), and is the skein file for the example in question; at present it's ignored.

For example:

	|$ intest/Tangled/intest inform7|
	|    -using -extension Locksmith.i7xp/Source/extension.i7x|
	|    -do -report C i7 Locksmith.i7xp/Build/Problems.html Locksmith.i7xp/Skein.skein|

reports on the failure of example C from the |Locksmith.i7xp| project. The
output is HTML, but sent to stdout by default; use something like

	|-to Locksmith.i7xp/Build/Problems-3.html|

to redirect this to a particular file.

The second special action is |-combine|. This assumes that the Inform app has
already performed |N| such tests, where |N >= 1|, and has called Intest with
the |-report| action on each in turn, redirecting the output to a series of
files. What |-combine| does is to read all of those files in and merge them
into a consolidated report, which, once again, it writes as HTML. The format
here is:

	|-combine <base-filename> -<N>|

The filenames of the individual reports are assumed to be |<base-filename>|
but with "-1", "-2", ..., tacked on before the file extension. Thus:

	|$ intest -using -extension Locksmith.i7xp/Source/extension.i7x|
	|    -do -combine Locksmith.i7xp/Build/Problems.html -4|
	|    -to Locksmith.i7xp/Build/Consolidated.html|

reads in

	|Locksmith.i7xp/Build/Problems-1.html|
	|Locksmith.i7xp/Build/Problems-2.html|
	|Locksmith.i7xp/Build/Problems-3.html|
	|Locksmith.i7xp/Build/Problems-4.html|

and writes out a consolidated report into

	|Locksmith.i7xp/Build/Consolidated.html|

@h Skein file testing.
In order to be used by the Testing panel in the Inform app, intest also supports the following:

	|-test-skein <file> <node-id>|

This reads the specified |.skein| file, looks for the node in it with the given ID, and runs intest's diff algorithm on the actual versus blessed transcript at that node. The output is in simple HTML format.
