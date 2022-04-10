How This Program Works.

An overview of how Intest works, with links to all of its important functions.

@h Prerequisites.
This page is to help readers to get their bearings in the source code for
Intest, which is a literate program or "web". Before diving in:
(a) It helps to have some experience of reading webs: see //inweb// for more.
(b) Intest is written in C, in fact ANSI C99, but this is disguised by the
fact that it uses some extension syntaxes provided by the //inweb// literate
programming tool, making it a dialect of C called InC. See //inweb// for
full details, but essentially: it's C without predeclarations or header files,
and where functions have names like |Tags::add_by_name| rather than just |add_by_name|.
(c) Intest makes use of a "module" of utility functions called //foundation//.
This is a web in its own right. There's no need to read it in full, but if
you haven't seen a Foundation-based program before, you may want to take a
quick look at //foundation: A Brief Guide to Foundation//.

@h Instructions and their blocks.
Intest is a C program, so it begins at //main//. This works out where Intest
is installed, which project Intest is to test, and where the file specifying
the universe of tests is, but otherwise soaks up the command line arguments
into an array of "instructions". For example, if the user typed:
= (text as ConsoleText)
	$ intest/Tangled/intest inform7 -verbose 1 2 Gelato
=
then the instructions array will be |-verbose|, |1|, |2|, |Gelato|.

//main// then calls out to //Historian::research// to look at the project's
test history log, and uses that to make substitutions: this is where |?3| might
be expanded into previous testing command number 3, or |6| might be expanded
into the test case name for currently-failing test number 6. In the case of
the example above, the instructions might now be |-verbose|, |Sackcloth|,
|Beatles|, |Gelato|.

Once //The Historian// is done, the instructions are passed to
//Instructions::read//, which parses them much more fully (see below) and
returns an //intest_instructions// object.

//main// then deals with a few incidental configuration switches -- for
example, turning on or off coloured terminal text output -- and then calls
//Globals::create_platform//. This creates the first global variable available to
testing scripts: |$$platform|, which might be, say, |"windows"|. A little later,
|$$workspace| follows, the path to the temporary filing system space used by
Intest. Globals always have these double-dollar-signed names, and are
also created by USING blocks (see below): see the functions //Globals::set//
and //Globals::get//. Globals have only one data type -- they all hold text;
but they are often just file system locations written out longhand. See
//Globals::to_pathname// and //Globals::to_filename//.

All is now prepared, and //main// simply hands over the //intest_instructions//
to //Actions::perform//. Once that completes, //Historian::write_up// is
called to update the history log, and Intest returns 1 if errors occurred or
0 if they didn't, in traditional Unix fashion. Note that a return code of 0
doesn't mean the tests all passed, only that they were all carried out; you
get a return code of 1 if, for example, you ask for a nonexistent test, but
if you ask to test |Gelato| and it fails, the return code is 0.

@ Let's take a closer look at how //Instructions::read// turns an array
like |-verbose|, |Sackcloth|, |Beatles|, |Gelato| into an //intest_instructions//
object. It divides the array into contiguous runs called "blocks", each of which
is either:

(a) an OPTIONS block, like |-verbose|, |-colours| or |-threads=N|, handled by the
command-line-reading functions in the //foundation// library;
(b) a DO block, introduced by |-do|, or by following directly on from the
conventional switches (a);
(c) a USING block, introduced by |-using|.

In the case of our example, there are just two blocks:
= (text)
	OPTIONS    DO
	-verbose   Sackcloth Beatles Gelato
=
USING blocks are passed to //RecipeFiles::read_using_instructions//. DO blocks
are passed to //Actions::read_do_instructions//, but only after the OPTIONS
block has been acted on, and after //RecipeFiles::read// has parsed the recipe
file for the project being tested. This ordering is important, because it means
the universe of available test cases is fully known before a DO block is parsed.
For example, it will be known that |Gelato| is the name of an available test case.

@h The Universe of Cases.
|-using| is seldom needed and could probably be dropped from Intest, but
USING blocks are essential and are needed on every run. This paradox is explained
by the fact that non-recipe commands in recipe files are in fact USING blocks.
Thus, if you type
= (text as ConsoleText)
	$ intest/Tangled/intest example all
=
you've given only a DO block (|all|), but if |example/Tests/example.intest| begins:
= (text as Delia)
	-cases 'example/Tests/Test Cases'
=
then it's as if you had typed
= (text as ConsoleText)
	$ intest/Tangled/intest example -using -cases 'example/Tests/Test Cases' -do all
=
because lines like that in the recipe file are sent to //RecipeFiles::read_using_instructions//
as USING blocks.

@ So what can USING blocks contain? A minimal amount of conditionality allows
for platform differences to be handled by |-if X|, ..., |-endif|: this works
by checking |X| against the |$$platform| global. |-set| calls //Globals::create//
to make new globals, and //Globals::set// to initialise them. But except for a
few side-shows like these, the business is to discover the universe of test cases.

That universe is stored as a list of //test_source// objects, each of
which holds a list of //test_case// objects coming from them. (There is one
//test_case// for each individually testable case.) Sources might be single
named files, files containing multiple test cases embedded in some elaborate
way (as with Inform 7 extensions), or directories holding batches of tests.

The work is done by //RecipeFiles::scan_directory_for_cases// and
//RecipeFiles::scan_file_for_cases//; the former calls the latter on its
contents, but the latter is also called directly when the USING command
names a single file rather than a directory.

//RecipeFiles::scan_file_for_cases// makes one or more cases out of a single
file. In simple cases, the file is the test case, and all we need do is hand
down to //RecipeFiles::new_case//. In more complicated cases, the file is in
some elaborate format inside of which test cases are embedded, and we have
to call //The Extractor// to extricate them: either way, though, the end
result is that //RecipeFiles::new_case// makes each //test_case// object.

What we get for our trouble is a function, //RecipeFiles::find_case//, which
returns the //test_case// for a test name like |Gelato|, or returns |NULL|
if no test has that name.

@h Instructions for action.
As noted above, DO blocks are parsed by //Actions::read_do_instructions//.
They typically tell Intest to perform an action on one or more test cases,
perhaps named individually, perhaps collectively. There are around 20 actions,
but the default is |-test|, so that our example DO block of |Sackcloth Beatles Gelato|
is actually parsed as if it were |-test Sackcloth Beatles Gelato|.

The DO block is converted into a list of //action_item// objects, each made
by //Actions::create//. For |-test Sackcloth Beatles Gelato|, there would be
three, just as if we had typed |-test Sackcloth -test Beatles -test Gelato|.
On the other hand, |-test all| produces only one //action_item//. This is
because an action item is an instruction to act on all test cases which match
a //case_specifier//, and while that can be an explicit name like |Sackcloth|,
it can also be a "wildcard" like |all| or |extensions|, or even everything in
a named group, or everything whose name matches a regular expression.
See //Actions::parse_specifier// for the syntax.

@h Performing actions.
At this point in the story, then, the instructions have been fully read, and
the recipe file has been read too. The universe of cases is known, and it's
known what the user wants us to do with which subsets of those cases. //Main//
has just called //Actions::perform//, and it's time for something to happen.

//Actions::perform// begins by calling //Hasher::read_hashes// to discover
any MD5 hashes of known-to-be-correct test cases, and finishes by calling
//Hasher::write_hashes// to update these. Otherwise, it works by acting on
each //action_item// in turn. Some actions, such as |-find| or |-catalogue|,
are taken care of immediately, but most, such as |-test| or |-bless|, are
"scheduled" by calling //Scheduler::schedule//. This does not act immediately
but, as the name suggests, schedules the tests for later: that later comes
at the end of //Actions::perform//, when it calls //Scheduler::test//.

The reason for doing that is that //The Scheduler// must allocate tests to
individual threads. The expectation is that if the host computer has $N$
processor cores, then there will be $N$ simultaneous testing threads running,
and it's //The Scheduler// which spreads the tests out, rather as if it were
dealing out a pack of cards to $N$ players sitting around a table.

Each thread runs from //Scheduler::perform_work//, a function which runs
through its tests -- its hand of cards, as it were -- and then marks itself
idle so that //Scheduler::perform_work//, which is asleep on the main thread
but wakes once per second to check on the workers, can then close it.
Once all threads have finished, and Intest is back to being a single-threaded
program, //Scheduler::perform_work// summarises the results.

@h Individual tests.
What the workers do is to call //Tester::test// on each //test// it is given.
A //test// object is essentially an action code, plus a //test_case//, plus
a work area in the file system -- each worker thread has its own work area,
since otherwise interference between them would create havoc; but successive
tests run by the same worker use the same work area, which is cleaned after
each use by //Tester::purge_work_area//.

The bulk of //Tester::test//, though, is an interpreter for the "recipe"
program -- that is, the Delia program assigned to the test case in question,
which has been precompiled into a quick-to-interpret form by //The Delia Compiler//,
something which was done back when the recipe file was read in.

@ The most complex algorithm in Intest is probably the one performing token
expansion, at //Tester::expand//. This expands a token like |$WORK/Example.inform|
by substituting in the current value of the variable |$WORK| -- note that these
are single-dollar, i.e. local to the current recipe, variables, as distinct from
the double-dollar, global, ones. That expansion process isn't so simple because
if |$WORK| expands to a filename with spaces in, then we may need to end up with
something which still ends up as a single shell command token -- see
//Tester::quote_expand// for how this is done.

@ When tests fail, it is usually because some output text doesn't match the
"blessed" text which had been expected -- only usually, because Delia recipes can
fail tests for quite a number of reasons. Still, this is the commonest case,
and then //The Differ// performs a Unix-style |diff| (i.e., summary of
differences) which can be reported back at the command line. //The Differ//
is a somewhat crude mechanism, probably the weakest part of Intest at present:
though it presents its output nicely, which is valuable, it has terrible
running time on really enormous outputs; in those cases, the Unix |diff| tool
would do rather better. More work could probably be done here.

@h Intest used inside the Inform GUI app.
On MacOS, the Inform application includes a copy of the |intest| binary, and
uses it to perform automated testing of the test cases in an extension, for
extension projects. This requires us to generate output in a different format,
since we're reporting back to the app rather than to the user at the command
line. See //The Reporter// for how this is done.

@h Adding to Intest.
Here's some miscellaneous advice for those who would like to add to Intest:

1. If what you want is to have a form of test which runs differently, see
first if this can be accomplished with a Delia recipe combined, perhaps, with
use of |-set| to create new global variables. The combination is quite potent.

2. But if that isn't good enough, try to do it with a minimal extension to the
Delia language. You'll need to make matching changes to //Delia::compile//
and //Tester::test//, and to add documentation to //Writing Intest Recipes//.

3. If that still isn't good enough, and what you really need is a different
way to process existing recipes, see if a new action -- such as |-test|,
|-bless|, |-rebless| and so on -- would meet your needs. If so, add this to
//Actions::read_do_instructions// and //Actions::perform//, and document it
at //Intest at the Command Line//.

4. Only if that really can't cope should you add a new OPTION block option,
but if so, see //Instructions::read// and //Instructions::respond//, and
again, document at //Intest at the Command Line//.

5. If what you want is to expand the universe of test cases in a new way --
say, to pull them down from some Internet-based repository rather than read
them from local files -- create a new category of //test_source//, and
add this to //RecipeFiles::read_using_instructions//.

6. As with any program built on Foundation, if you are creating a new class of
object, don't forget to declare it in //Basics//.
