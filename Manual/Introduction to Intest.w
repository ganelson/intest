Introduction to Intest.

What Intest is, and a simple example of what it can do.

@h Introduction.
Intest is a command line tool for testing command line tools. It was
originally written for testing the Inform 7 compiler, and has been used
heavily and continuously for that purpose since 2004. But it can in fact
test any command-line tool with broadly textual output. While it's a natural
sidekick for the literate programming tool Inweb, it can work just as easily
on programs written by other means.

Intest is at its best when running a batch of tests, each of which can follow
a complex multi-stage sequence if necessary. Tests are automatically spread
across multiple threads so that the batch can be finished as soon as
possible, and results are tidily collated. Intest has a command-line syntax
which makes a sort of conversation possible: start by testing a batch, then
retest those which fail, fixing them one by one, and so on. For example,
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject all
	myproject -> cases: [1] [2] [3] [4] 
	Discrepancy at line 7:
	    Planet is: Joopiter
	[5] planets produced incorrect output
	[6] [7] [8] [9]
	  8 tests succeeded but 1 failed (time taken 0:02, 9 simultaneous threads)
	Failed: 1=planets
=
Suppose we go fix that bug, and then retest:
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject 1
	Expanded to: ?322. planets
	[1] planets passed
=
Note that |1| was understood by Intest here as referring to the test case
|planets| which failed earlier. Intest is recording a history of recent
tests run, too: this one was test run |?322|. We could have listed those by
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject ?
=
and recalled any of them by number:
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject ?315
	Repeating: ?315. rockets moons
	[1] rockets passed
	[2] moons passed

@h Recipes.
Intest assumes that each project will have its own universe of tests.
These can take many forms, but the commonest are to give valid input and
check to see some expected output, or else to give invalid input and check
to see that some expected error message is produced.

Each individual test is performed by following a "recipe". Recipes are simple
mini-language called Delia, which sits on top of the host operating system's
command-line shell. For example, here is Delia code for testing what ought to
be a valid input to a tool called |zap| inside the |myproject| folder:
= (text as Delia)
	set: $A = $PATH/_actual/$CASE.txt
	set: $I = $PATH/_ideal/$CASE.txt
	step: myproject/zap $PATH/$CASE.txt >$A 2>&1
	or: 'failed zap' $A
	show: $A
	match text: $A $I
	or: 'produced the wrong output'
	pass: 'passed'
=
This looks more forbidding than it is. Variables start with a dollar, as in
most Unix mini-languages: they usually hold filenames. |$CASE| is the name
of the current test case: perhaps "planets". |$PATH| is the pathname to its
folder, which might be, for example, "myproject/tests". What happens is:
= (text as Delia)
	set: $A = $PATH/_actual/$CASE.txt
	set: $I = $PATH/_ideal/$CASE.txt
=
This sets two filenames -- it doesn't create these files, simply creates
two names. |$A| is going to be the actual output printed out by the program
being tested, while |$I| is the ideal output, that is, what it should have
printed. Next:
= (text as Delia)
	step: myproject/zap $PATH/$CASE.txt >$A 2>&1
=
A "step" is a stage in a test which involves issuing a shell command, and
which passes or fails according to the exit code from that command, exactly
as it would in a tool like |make|. We're going to assume |zap| is a simple
sort of program, which takes one command-line argument -- a filename --
does something with that file, and prints out something interesting about it.

Intest substitutes in values for the variables, so the actual shell command
might be:
= (text as ConsoleText)
	$ myproject/zap myproject/tests/planets.txt >myproject/tests/_actual/planets.txt 2>&1
=
which uses bash shell notation to redirect both printed output, and error
messages, to the |$A| file. That, as promised, is the "actual output".

The next line in the recipe is then:
= (text as Delia)
	or: 'failed zap' $A
=
This tells Intest to halt the test if the shell command failed (i.e., if
|zap| exited with a non-zero exit value). Intest uses the brief epitaph
"failed zap" when summarising what happened, and prints out |$A|,
because presumably it ends with some error messages which the tester will
want to see.

So the recipe is only continued if, in fact, |zap| did not produce error
messages. The next line is not quite what it seems:
= (text as Delia)
	show: $A
=
This tells Intest that if the tester ran the test specifying |-show| on
the command line then |$A| is the right file to print out. If the tester
didn't say |-show|, we print nothing here, and continue. The next steps
in the recipe are more consequential:
= (text as Delia)
	match text: $A $I
	or: 'produced the wrong output'
=
This does what it looks as if it should, but it has hidden powers. If the
tester hasn't yet created a file of ideal output, then there's nothing to
compare against. In that case Intest doesn't fail the stage, but it does
mark it in the summary:
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject planets
	-1- planets passed
=
The notation |-1-|, rather than the more usual |[1]|, conveys that the
test was incompletely passed in this way. This is easy to fix. If we're
happy with the actual output, we "bless" it:
= (text as ConsoleText)
	$ intest/Tangled/intest -from myproject -bless planets
	[1] planets passed
=
With |-bless| specified, when the recipe hits:
= (text as Delia)
	match text: $A $I
=
Intest sets the ideal output to the actual output: the two then necessarily
match, so the stage passes. (It's also possible to |-curse| a test, which deletes its ideal
output, or to |-rebless| it, which replaces the current ideal output
in favour of the current actual output -- in effect, it performs a curse
immediately followed by a blessing.)

Either way, if the recipe is still running at this point, all is good:
|zap| produced no error messages, and we have output which is not known
to be incorrect. So we conclude with a triumphant:
= (text as Delia)
	pass: 'passed'
=
Recipes can be substantially longer and more elaborate, running through
a sequence of tools, or running the same test material in a sequence of
different ways. The recipes used by the main Inform compiler occupy about
400 lines like the above, though always with the same basic manoeuvres
over and over again. A typical test batch for that project involves
over 2000 cases. Intest is a simple tool at heart, but it was written
with an eye to speed and flexibility.

@h Installation.
Intest is a "literate program", and to compile it from source you should
first obtain the literate programming tool Inweb. (Both are available from
Github.)

To begin, place the distribution directories |intest| and |inweb| in the
same parent directory, and then change working directory to that. Thus, you
should reach:
= (text as ConsoleText)
	$ ls
	intest   inweb
=
(and perhaps lots of other stuff too). Be sure to make Inweb first: see
its own documentation for that. Then:
= (text as ConsoleText)
	$ inweb/Tangled/inweb intest -makefile intest/intest.mk
=
This makes the makefile we will use. It will automatically be configured
suitably for the operating system we're using: the MacOS version of Inweb
will make us a MacOS version of this makefile, and so on. Now we can make:
= (text as ConsoleText)
	$ make -f intest/intest.mk
=
All being well, you now have a working Intest. The executable is in
|intest/Tangled/intest|, so:
= (text as ConsoleText)
	$ intest/Tangled/intest -help
=
should verify that it's in working order. A more interesting test is:
= (text as ConsoleText)
	$ intest/Tangled/intest -from inweb all
=
which runs the Inweb test suite (a very modest one, as it happens).

Users of, for example, the |bash| shell may want to
= (text as ConsoleText)
	$ alias intest='intest/Tangled/intest'
=
to save a little typing, but in this documentation we always spell it out.

@ When it runs, Intest needs to know where it is installed in the file
system. There is no completely foolproof, cross-platform way to know this
(on some Unixes, a program cannot determine its own location), so Intest
decides by the following set of rules:

- If the user, at the command line, specified |-at P|, for some path
|P|, then we use that.
- Otherwise, if the host operating system can indeed tell us where the
executable is, we use that. This is currently implemented only on MacOS,
Windows and Linux.
- Otherwise, if the environment variable |$INTEST_PATH| exists and is
non-empty, we use that.
- And if all else fails, we assume that the location is |intest|, with
respect to the current working directory.

If you're not sure what Intest has decided and suspect it may be wrong,
running Intest with the |-verbose| switch will cause it to print its belief
about its location as it starts up.

@ Intest returns an exit code of 0 if successful, or else it throws errors
to |stderr| and returns 1 if unsuccessful. Successful means that it did what it
was asked to do: if it was asked to conduct a test and the test failed,
Intest was still successful (the test was after all conducted), so it
returns 0.
