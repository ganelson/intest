Writing Intest Recipes.

A guide to writing in Delia, Intest's recipe language.

@h Writing Delia.
Recipe definitions are written in a very simple mini-language called Delia,
for reasons which English users of Intest will appreciate. Had Intest been
written by an American, it would have been called Julia.

This example recipe shows the basic syntax. In this recipe, which creates three
"variables" |$A|, |$I| and |$SOURCE|, a command-line program called |launcher|
is to be called using |$SOURCE| as the filename of its input. Its output is
then redirected into the file |$A|, which is compared against |$I| to see
if the right output was printed.

= (text as Delia)
	set: $SOURCE = $PATH/$CASE.txt
	set: $A = $PATH/$CASE--A.txt
	set: $I = $PATH/$CASE--I.txt

	step: launcher $SOURCE >$A 2>&1
	or: 'launcher produced error messages' $A

	exists: $I
	or: 'launcher produced no errors, but no blessed output existed'

	match text: $A $I
	or: 'produced incorrect output'

	pass: 'passed'
=

In this example the test has four possible outcomes at which it might
halt: at the three |or:...| lines, which halt a test because the previous
instruction failed in some way; or, if things go better, on the last line
where the |pass:| instruction says that the test has completed as it should.

@h Syntax and tokens.
Blanks lines and lines beginning with exclamation marks |!| are ignored.
All other lines must have the form
= (text as Delia)
	command: token1 ... tokenN
=
where different commands need different numbers of "tokens".

The command and its tokens must occupy a single line and no comment is
allowed at the end of it. Quotation marks can be used to make multiple words
a single token; thus:
= (text as Delia)
	exists: 'My Tests/output.txt'
=
is a command plus a single token, not two. A backslash can be used to escape
the quotation mark when inside quotes.

@h Variables.
Delia has just one data structure: a set of named variables. The language has
no concept of "types": all data is text. A variable can hold any amount of
text, including none. Note that there is a difference between a variable
existing but holding the empty text as its value, and not existing at all.

In practice, this text is usually used to hold filenames, pathnames, or
fragments of command-line commands not yet issued, but it can in principle
be used for almost anything.

@ Variables can be either "global", written |$$NAME|, or "local", written
|$NAME|. A Delia recipe can create and modify local variables freely, but
can neither create nor modify globals, which are handed down to it from above.
They are therefore constant throughout the life of a test which is running, and
they have the same value for all tests being conducted in the same run of
Intest. The following globals are automatically defined:

(1) |$$platform|, as mentioned above, which is a string such as |osx| or |windows|.
Avoid using this where possible. All other global variables are created
by the |-set| command at the top of the recipe file: see above.

(2) |$$project| is the path to the project being tested.

(3) |$$internal| is the path to the Inform internals directory, assumed to be
|inform7/Internal| unless the |-internal| switch has said otherwise. This will
only be useful for testing Inform-related programs, of course, and not always then.

(4) |$$workspace| is the path to a directory where Intest can write temporary
files as it pleases. Do not use this for throwaway files in the course of a
test unless you are quite sure multiple tests running at once will not interfere
with each other: if you are not sure, use |$WORK| instead (see below).

(5) |$$nest| is used only internally, and on automatic tests of extensions or
kits for Inform: it then holds the path to the directory or "nest" of resources
from which the extension or kit seems to be drawn.

Other global variables may have been created using |-set| in the intest
file, for which see //The Universe of Cases//, or at the command line.
For example,
= (text as ConsoleText)
	$ ../intest/Tangled/intest inform7 -set WORD=plugh all
=
runs the tests for |inform7| with the global variable |$$WORD| set to |plugh|.

@ For the most part, a Delia recipe can create its own local variables quite
freely, but it doesn't begin with a completely blank slate. As it starts:

(1) |$CASE| is the name (not the title, if that differs) of the test case.

(2) |$TITLE| is the title (not the name, if that differs) of the test case.

(3) |$PATH| is the pathname to the directory which the test case is in.

(4) |$TYPE| is the type of test case this is: |case|, |problem|, |example|,
|extension|.

(5) |$WORK| is the pathname of a directory set aside by Intest for any intermediate
files we might need to produce during the test process -- these must all be
temporary files we can happily lose when the test is completed. The real
usefulness of this comes when Intest is running a batch of tests across
multiple threads, because those threads each need their own independent work
area to avoid stepping on each other's feet. Provided the recipe uses |$WORK|,
it never needs to think about this complication.

(6) If the Intest file specifies "stipulations" on the test case, those set
local variables for it: see //The Universe of Cases//. In this example,
the recipe |[Reactor]| starts with the given settings of |$TEMP| and |$STATUS|.
= (text as Delia)
	-cases [Reactor:TEMP=Hot:STATUS=Safe] 'fusionreactor/Tests/HotCases'
	-cases [Reactor:TEMP=Cold:STATUS=Safe] 'fusionreactor/Tests/ColdCases'
	-cases [Reactor:TEMP=Hot:STATUS=Unsafe] 'fusionreactor/Tests/UnsafeCases'
=

(7) If the test case itself contains annotations, those are also used to
create local variables which the test starts with. In the following example,
any test of |Nettles| would begin with the recipe having appropriate values
of |$LANGUAGE|, |$FOR| and |$INTOPTIONS|.

= (text)
	Test: Nettles
	Language: Basic
	For: Glulx
	IntOptions: -u -q -dataresourcetext '3:$PATH/Nettles--X.txt'
=

@ The special variable |$SCRIPT| is created by the |extract:| instruction
(see below), and is only useful for testing Inform. It is created if one
of two things happens:

(a) A text file exists in the same directory as the test case, and with the
|--S| filename suffix. For example, if the test is in |zap/Tests/Cases/DeathRay.txt|,
then Intest will look for the file |zap/Tests/Cases/DeathRay--S.txt|. If that
file exists, |$SCRIPT| will be set to its filename.

(b) The test case contains a sentence of source text in the form
"Test me with "Command 1 / Command 2 / ..."." If it does, Intest will
use a generic script which types TEST ME, then QUIT, then Y (to confirm
quitting), and will set |$SCRIPT| to that filename.

@ The special variable |$HASHCODE| is created by the |hash:| instruction:
see below.

@ When tinkering with recipes, it's sometimes very helpful to be able to
see what's happening to all of these variables. Running Intest in its
|-verbose| mode will do that. For example, if we run Intest on its
example project, we can sit back and watch what it's doing:
= (text as ConsoleText)
$ intest/Tangled/intest intest/Examples/dc -verbose minus
...
Global variables:
      $$platform = macos
      $$project = intest/Examples/dc/Tests
      $$internal = inform7/Internal
      $$workspace = /Users/gnelson/Natural Inform/intest/Workspace
Local variables at start:
      $CASE <--- minus
      $TITLE <---
      $PATH <--- intest/Examples/dc/Tests/Cases
      $WORK <--- /Users/gnelson/Natural Inform/intest/Workspace/T0
      $TYPE <--- case
Recipe execution:
0001: 	mkdir: $PATH/_actual
shell: mkdir -p 'intest/Examples/dc/Tests/Cases/_actual'
0002: 	mkdir: $PATH/_ideal
shell: mkdir -p 'intest/Examples/dc/Tests/Cases/_ideal'
0003: 	set: $A = $PATH/_actual/$CASE.txt
      $A <--- intest/Examples/dc/Tests/Cases/_actual/minus.txt
0004: 	set: $I = $PATH/_ideal/$CASE.txt
      $I <--- intest/Examples/dc/Tests/Cases/_ideal/minus.txt
0005: 	step: dc $[$PATH/$CASE.txt$] >$A 2>&1
shell: 'dc'  '-e'  '10 3 - p' >'intest/Examples/dc/Tests/Cases/_actual/minus.txt'  2>&1
0006: 	or: 'failed dc' $A
0007: 	show: $A
0008: 	match text: $A $I
0009: 	or: 'produced the wrong output'
0010: 	pass: 'passed'
=

@h Expansion.
Variables are only useful for their values, and their values are used by
means of "expansion".

When Delia reads the token |$PATH/$CASE.txt|, for example, it substitutes in
the values of |$PATH| and |$CASE|. If |$PATH| is |zap/Tests| and |$CASE| is
|planets|, the result would be |zap/Tests/planets.txt|. This process is called
"expansion", and Delia applies it to almost every token.

Expansion fails with an error if the local variable named does not in fact
exist. Thus Intest will refuse to expand |My$BARGAIN|, rather than expand it
to just |My| or leave it as it stands, if the variable |$BARGAIN| does not
exist. (This is even true if the variable |$BARGAI| should exist.)

The instruction |set:| either creates a new local variable, or changes the
value of an existing one:
= (text as Delia)
	set: $NAME = VALUE
=
Note that the |VALUE| token here is expanded, but the |$NAME| token is not,
for obvious reasons. This is one of the exceptions hinted at above.

@ A wrinkle here is that if the setting value has multiple tokens:
= (text as Delia)
	set: $NAME = VALUE1 VALUE2 ...
=
then they are each "quote-expanded", rather than being simply "expanded".
This basically means that the value is meant to be used in place of a string
of tokens, rather than as a fragment or the whole of a single token.
For example:
= (text as Delia)
	set: $OPTIONS = -no-warnings -p=10 -to $FILE.txt
=
sets the value to be
= (text as Delia)
	'-no-warnings' '-p=10' '-verbose' '-to' 'My File.txt'
=
This precaution is in case, as happened in this example, expansion of one of
the tokens, |$FILE.txt|, brought in new white space -- here, the space between
"My" and "File".

@ The instruction |default:| is entirely the same as |set:|, except that it
takes effect only if the variable does not yet exist. Thus:
= (text as Delia)
	default: $FUEL = Kerosene
=
is exactly equivalent to
= (text as Delia)
	ifndef: $FUEL
		set: $FUEL = Kerosene
	endif
=
but is less laborious.

@ Quote-expansion is not always what we want. For example, suppose we further
defined:
= (text as Delia)
	set: $MOREOPTIONS = $OPTIONS -lang=en-uk
=
We would then get the value:
= (text)
	'\'-no-warnings\' \'-p=10\' \'-verbose\' \'-to\' \'My File.txt\'' '-lang=en-uk'
=
which of course is wrong. We avoid this using a backtick to suppress quote
expansion of the first token:
= (text as Delia)
	set: $MOREOPTIONS = `$OPTIONS -lang=en-uk
=
which gets it right:
= (text)
	'-no-warnings' '-p=10' '-verbose' '-to' 'My File.txt' '-lang=en-uk'
=
Note that quote expansion respects the Unix shell redirection markers like
|>file| or |2>&1|, quoting just the file parts.

@ Quote-expansion also supports one more feature: the token |$[filename$]|
expands to the (tokenised and further expanded) contents of the file named.
Thus for example if the file |Frog.txt| contains the words "never turn your
back on a frog", then
= (text as Delia)
	$[Frog.txt$]
=
will quote-expand to:
= (text)
	'never' 'turn' 'your' 'back' 'on' 'a' 'frog'
=
By default, the contents of the file will themselves be expanded, if they
contain names with |$| or |$$| prefixes. To avoid that (and thus treat dollar
signs in the file as being literal), use yet another backtick:
= (text as Delia)
	$[`Toad.txt$]
=

@ Finally, the syntax
= (text as Delia)
	${Salamander.mp3$}
=
will quote-expand to an MD5 hash of the file named. This should exactly match
what the |md5| tool supplied on most Unixes would give; for example, an empty
file would quote-expand to |d41d8cd98f00b204e9800998ecf8427e|.

Two special modified versions of this are available for taking hashes of
story files for the Z-machine or Glulx, which are useful for tests of Inform.
Thus |${zmachine:Salamander.z3$}| or |${glulx:Salamander.ulx$}| take hashes
in a way which masks certain bytes of their headers as zeros; here we match
the conventions used by Andrew Plotkin's test program for Inform 6. The idea
is that we want to ignore things like the time-stamp and compiler version,
which will change daily.

@ Note that the filename is itself expanded before use, so that it can be
defined using variables. This can be very useful when we want to test a
program which takes its input mainly in the form of command-line arguments,
rather than from a file. See the example supplied with Intest for testing
"dc", the very old-school reverse Polish notation calculator supplied with
most Unix systems (including MacOS). In that example, a test case such as
|dc/Tests/Cases/plus.txt| contains what to put on the command line when
running dc:
= (text)
	-e '1 1 + p'
=
The important step in the recipe for using this then reads:
= (text as Delia)
	step: dc $[$PATH/$CASE.txt$]
=
and this causes Intest to run the command:
= (text as ConsoleText)
	$ dc -e '1 1 + p'
=
which produces the concise output "2".

@h Control flow.
As we shall see, there are conditionals in the Delia language, but no loops
and no subroutines, macros, function or procedure calls. Delia is intentionally
not Turing-complete: it tries to balance flexibility with simplicity.

A test therefore flows from top to bottom of the recipe, perhaps skipping some
stages because of conditionals. But it doesn't always get to the bottom, because
a multi-stage test can end early for several reasons.

One way a test can halt is if it runs into one of the "stopping commands":

|pass: 'NOTE'|. Stops the test and marks it a success. The text |'NOTE'|
is optional, and is a summary used when Intest prints its results.

|fail: 'NOTE' FILE|. Stops the test and marks it a failure. The text |'NOTE'|
is optional, and is a summary used when Intest prints its results. The |FILE|,
which is also optional, is then printed out when Intest describes what went
wrong.

But tests can also halt because one of its steps or matches fails. For example,
perhaps a test needs to run a C compiler as a step, and this unexpectedly
produces error messages rather than compiling. When that happens, a test
will usually stop immediately and will be marked as a failure. However:

|or: 'NOTE' FILE|. If the step or match performed immediately before this line
failed, the failure message |'NOTE'| is used. The |FILE|, which is optional,
is then printed out when Intest describes what went wrong. For example:
= (text as Delia)
	step: dc -e $EXPRESSION
	or: 'dc produced an error'
=

More generally, the conditional |iffail:| can be used, which causes the rest
to continue despite the failure of a step. In fact, that last example is
equivalent to:
= (text as Delia)
	step: dc -e $EXPRESSION
	iffail:
		fail: 'dc produced an error'
	endif
=
|iffail:| can thus be used to send tests down differing paths if steps fail.

@ Control also stops, with a pass for the test, if it runs into a |show: ...|
command of the right sort when the tester is looking for that. For example,
suppose the command being used is:
= (text as ConsoleText)
	$ intest/Tangled/intest inform7 -show-transcript Pine2
=
The tester then runs the test case |Pine2| in hopes of running into an
instruction like this:
= (text as Delia)
	show: transcript $TF
=
If it finds such an instruction, it prints out the file which |$TF| (i.e.,
the second token, whatever it is) and ends the test then and there.

If the tester is not looking to show a transcript, it will pass over
|show: transcript ...| doing nothing.

@ If a target is considered especially important to see, it can be given
the empty target name. The command for that is then |show: $X|, with just
one token, and the tester looks for this in response to just |-show|
on the command line, rather than a more general |-show-TARGET|.

@ If the file does not exist for some reason, the test continues, but the
step is considered a fail. This possibility can be picked up by placing
an |or:| immediately following:
= (text as Delia)
	show: transcript $TF
	or: 'heaven knows why, but the transcript file does not exist'
=

@h Steps.
A "step" is a shell command issued to the host system: it actually does
something as part of the test, in other words, rather than simply preparing
to do things or looking at the result.

There are two sorts of step:

|step: COMMAND|. Runs the shell command |COMMAND|. The step passes if the
command returns the exit code 0, which for Unix utilities conventionally
means that no errors occurred. It fails on all non-zero exit codes.

|fail step: COMMAND|. The same as |step:|, but this time expecting a non-zero exit
code, and failing on zero.

|debugger: COMMAND|. The same as |step:|, but runs the command in only when
the test is being run by the |-debug| action. The idea is to do something
like this:
= (text as Delia)
	debugger: lldb -f launcher -- $SOURCE
	step: launcher $SOURCE >$A 2>&1
	or: 'launcher produced error messages' $A
=
The idea is that if the test is mysteriously crashing at this stage then
running it with |-debug| will divert into the debugger instead, what that
crash can be investigated.

@ What happens if a step "fails"? The answer is that nothing happens and the
recipe simply carries on, unless the next line is an |or:| command, as noted
above. So if the shell command doesn't follow Unix conventions with its exit
code, or if we just don't care, we needn't worry that the test will halt. It
will only do so on our explicit instruction.

@h Matches.
Matching simply means comparing the contents of two files.

|match text: A B|. Here |A| and |B| are text files, and Intest will show
diffs if they disagree.

|match platform text: A B|. The same, but now forward and backslashes are
counted as being equivalent to each other. This enables filenames printed
out on Windows to be compared with those printed out on other platforms.

|match binary: A B|. Now they are binaries, so Intest will simply report
that they disagree, if they do.

|match folder: A B|. This time they are folders (i.e., directories), and
Intest will expect the entire contents (other than any hidden files
beginning with |.|) to agree. This recurses downwards through any
subfolders.

All of these are commands which can pass or fail, so that they can be followed
by an |or| command taking effect only if they fail. If a test fails because
of a failed |match|, then the command line options |-diff| or |-bbdiff|
cause these tools to be invoked on |A| and |B|, the two matched files which
failed.

There are also four Inform-specific forms of matching: |match problem|,
|match i6 transcript|, |match frotz transcript| and |match glulxe transcript|,
which are roughly the same as |match text|, but display differences in a more
contextual way. Details here would be tiresome: see the Intest source code.

@ However, the |match| commands have a very useful side-effect if the test
is being run by |-curse|, |-bless| or |-rebless| at the command line. If we
are cursing, then |match text: A B| will delete |B|, the ideal form. If we
are blessing, then |match text: A B| will copy |A| into |B|, thus declaring
that the actual form this time should serve as ideal from now on.

@ |match| is also just a little forgiving, in that it allows a few not quite
equal texts to "match" each other. In particular:

On a |match text: A B|, a line of A and a line of B will match even if they
disagree about the decimal number appearing in a use of |/Tn/|, where |n|
is that number. For example, these two lines match:
= (text)
	Opened intest/Workspace/T4/intermediate.txt
	Opened intest/Workspace/T11/intermediate.txt
=
This example should suggest why -- when Intest is spreading tests across
multiple processors, we cannot predict which thread number a test will run
on; and as a result, we cannot say which sandbox area of the file system
it is allowed to use. That may cause the program under test to print
output which will contain the thread number it is running on. But since
we want to verify that output, we need to allow such output to match. What
happens internally is that both lines are converted to
= (text)
	Opened intest/Workspace/Txx/intermediate.txt
=
and then, of course, they match exactly. This makes runs of the same test
comparable even when the runs occur on different threads.

This is the only important case of "forgiveness": the others apply only
when matching forms of file specific to Inform. Those make similar
arrangements to ignore the exact build number of Inform when it leaks
out into I7 console output or into story file transcripts.

@h Files and directories.
There is one other commonly used pass/fail command:

|exists: F|. This passes if the file at |F| exists on disc, and fails otherwise.
For example,
= (text as Delia)
	exists: $TRANSCRIPT
	or: 'no transcript was written'
=
(When testing a program which doesn't return exit codes, sometimes the best
way to see whether it worked or not is to see whether it produced any output.)

@ In addition, Delia has a very limited ability to write to the file system itself:
= (text as Delia)
	copy: FROM TO
=
copies a file. This should only be used to copy into the work area |$WORK|.

= (text as Delia)
	mkdir: PATH
=
ensures the existence of directory at the given |PATH|. (Again, this should
be used only to make subdirectories of |$WORK|.)

There is intentionally no deletion command. You could fake this easily with
|step: rm ...|, but don't try to clean up the work area yourself: Intest will
handle that automatically.

@h Conditionals.
As noted above, Delia has no loops. But it does have one control construct:
an if/then/else command, working in the obvious way.
= (text as Delia)
	if: TOKEN EXPRESSION
	    ...
	else
	    ...
	endif
=
The |else| clause is optional, and these conditionals can be nested in the
usual way.

What the test does is to expand both |TOKEN| and |EXPRESSION|, and then see
if the expanded token matches the regular expression defined by the expanded
expression. That can be just a simple textual match:
= (text as Delia)
	if: $CASE Balloons
=
tests if the current test case name is "Balloons". On the other hand,
= (text as Delia)
	if: $CASE Party-%d+
=
would match cases such as |Party-12|, because |%d+| is regular expression
syntax for "one or more digits here".

The regular expression syntax here is a slightly non-standard one used in
the Inform tools, and it's not intended for anything elaborate. |%C|
matches any non-whitespace character, |%c| any character, |[abc]| matches
any of the characters |a|, |b| or |c|, |+| means "one or more", |*| means
"0 or more", but look out for the fact that a space means "any amount
of whitespace".

Moreover, if the |EXPRESSION| is quoted, the quotes are removed again
before the test is performed. Thus:
= (text as Delia)
	if: $CASE 'More Balloons'
=
then |$CASE| is tested against the text |More Balloons|, not |'More Balloons'|.
Similarly,
= (text as Delia)
	if: $CASE ''
=
tests if |$CASE| is the empty text.

@ An alternative condition is |if exists: FILE| tests if the named file
exists. This can allow for certain checks to be performed only where
there is something to check against, for example.

@ |ifdef: $NAME| is true if and only if the local variable |$NAME| exists.
Note that this will pass if |$NAME| has the empty text has its value, i.e.,
is currently blank: it will only fail if the variable has never been created.
Note also that some variables are automatically created before the recipe
even begins -- see above.

|ifndef: $NAME| is the usual opposite of this, i.e., it is true if and only
if |$NAME| has never been created.

@ As we have seen, |iffail:| is true if and only if the previous step or
match failed, and |ifpass:| is similarly defined. (Note that these cause
execution to continue where it otherwise would not.)

@ |if showing: ITEM| is true if and only if the test is being run with
the action |-show-ITEM|. This is useful if you want a recipe to make it
possible to show some elaborate intermediate data which is usually not
needed at all: with |if showing:|, you can have that data created only
when somebody wants to see it.

@ |if compatible: FORMAT COMPATIBILITY| is true if and only if the
Inform platform text |FORMAT| matches the compatibility text |COMPATIBILITY|.
For example:
= (text as Delia)
	if compatible: inform6/32 'Glulx only'
=
will be true. This is meaningful only when testing Inform, of course.
Errors are generated if either |FORMAT| or |COMPATIBILITY| is malformed.

@ |if format valid: FORMAT| is true if and only if |FORMAT| is a valid
Inform platform text. For example:
= (text as Delia)
	if format valid: Python/gil
=
is currently not true.

@ Suppose the program to be tested produces output which takes a long time
to verify the correctness of. (This is the case for Inform 7, because its
output needs to be fed through Inform 6 and then executed in a virtual
machine before any results can be seen. Both steps take a second or so,
and with 2000 tests and only 3600 seconds in an hour, that's significant.)

An obvious optimisation is to check that the intermediate output matches a
version already known to work. This is not as easy as it seems, though, if
that intermediate output is very large, and if the exact contents of the
output are allowed to change from time to time (provided that the end
functionality does not). Intest provides for this by allowing each test
case to perform one "hash", that is, reducing a text file to a hash code.
These hash codes are then cached between runs of Intest, which always
knows the last hash value found on a run of the test case which passed.

All of that is accomplished with two global variable settings and one
single command. Note that the two globals have to be set outside of Delia;
they aren't dependent on any single test case. They are:

|-set hash_utility HASHPROGRAM|, which tells Intest what program to use
in order to determine the hash: this is expected to behave like the Unix
tool |md5|, in that the shell command |utility FILENAME| would print a
hash code for the named file and then halt. But if all you want is an |md5|
hash, there is no need to set this variable, because Intest has a built-in
implementation of md5 and can use that instead.

|-set hash_cache FILE|, which tells Intest where to store known-good hash
values in between runs. If this is not set, hash values may be generated
but are not cached, so that there is little benefit.

|hash: FROM TO| takes a hash value of the file |FROM| and writes it into
a (very short) file |TO|. This is a pass/fail command, which means that it
can be followed by an |or:|, but perhaps unexpectedly, it fails if the
checksum is the same as the last time this checksum was performed for the
test case in question. That enables something like this:
= (text as Delia)
	hash: $I6SOURCE $WORK/checksum.txt
	or: 'passed (matching cached I6 known to work)'
=
(Uniquely, the |or:| in this case causes the overall test to pass, not fail.)
Besides being written to the file, the hash value is also stored in the
local variable |$HASHCODE|.

@ And finally, a great convenience for testing Inform 7, but useless for
anything else:

|extract: FILE VM|. This extracts a clean copy of the Inform 7 source text in
the test case and stores it in the |FILE|. For a test case which is a |case|
or |problem|, that's simply a file copy, but for an |extension|, for example,
it's a non-trivial operation. |VM| should be the Inform virtual machine
in question, |Z| or |G|. If the |FILE| contains a command script, this is
automatically written into the local variable |$SCRIPT|.

@h Cautionary tale about encodings.
When we first ported //inweb// and //intest// to Windows, we realised that
locale differences meant that some tests weren't portable between MacOS and
Windows. The issue was that the console environment (i.e., the standard
output and standard error stream) was encoded as UTF-8 on MacOS, but ISO Latin1
on Windows: this is the "locale", in operating system jargon.

As a result, a test which recorded the console output on a Mac could not be
compared with the same test on Windows if that output included non-ASCII
characters. That would affect any Delia step written like this:
= (text as Delia)
	step: insomething/Tangled/insomething whatever >result.txt
=
in that the program might be operating identically on these platforms but
still produce a different |result.txt| file on Mac vs Windows, one being
UTF-8 encoded, the other ISO.

To get around this, all of the Inform tools have been given a command-line
setting:

|-locale LOCALE=ENCODING| where |LOCALE| is one of |shell| or |console|, and
|ENCODING| is one of |platform|, |utf-8| or |iso-latin1|. (The |platform|
encoding means "whatever is normal on the current platform".) Running with the
|-verbose| option in //inweb// or //intest// will show the locales being used:
= (text as ConsoleText)
	$ intest/Tangled/intest -verbose
	Installation path is /Users/gnelson/dev/intest
	Locales are: shell = utf-8, console = utf-8
	$ intest/Tangled/intest -locale console=iso-latin1 -verbose
	Installation path is /Users/gnelson/dev/intest
	Locales are: shell = utf-8, console = iso-latin1
=
It's probably best not to change the |shell| locale, which affects the
encoding on (a) environment variables, (b) filenames when scanning directories,
and (c) command-line parameters, either in or out. Changing the |console|
locale, though, effectively makes standard output from an Inform tool conform
to the given locale. So:
= (text as Delia)
	step: insomething/Tangled/insomething -locale console=utf-8 whatever >result.txt
=
would produce the same result on MacOS as on Windows.
