[Instructions::] Command Line Arguments.

To parse the command line arguments with which intest was called,
and to handle any errors it needs to issue.

@h Setting up.

=
intest_instructions Instructions::read(int argc, text_stream **argv,
	pathname *home, filename *intest_script) {
	@<Register some configuration switches with Foundation@>;
	intest_instructions args;
	@<Initialise the arguments state@>;
	Instructions::read_instructions_into(&args, 1, argc, argv, home);
	return args;
}

@ Most of the Inform tools hand over the whole business of command line
parsing to Foundation, but Intest can only partly do that, because our
command-line syntax is too complicated. Still, we register some switches
and heading text in the normal Foundation way:

@e PURGE_CLSW
@e HISTORY_CLSW
@e COLOURS_CLSW
@e VERBOSE_CLSW
@e THREADS_CLSW

@<Register some configuration switches with Foundation@> =
	CommandLine::declare_heading(
		L"This is intest, a command-line tool for testing command-line tools\n\n"
		L"intest PROJECT OPTIONS -using RECIPEFILE -do INSTRUCTIONS\n\n"
		L"PROJECT is the home folder of the project to be tested\n\n"
		L"-using RECIPEFILE tells intest where to find test recipes: default\n"
		L"is PROJECT/Tests/PROJECT.intest\n\n"
		L"-do INSTRUCTIONS tells intest what to do with its tests:\n"
		L"    ACTION CASE1 CASE2 ... performs the given action, which may be:\n"
		L"    -test (default), -show, -curse, -bless, -rebless, -open, -show-i6\n"
		L"    CASEs can be identified by name, or by 'all', 'cases', 'problems', etc.\n"
		L"    a bare number as a CASE means this case number in the command history\n\n"
		L"'intest ?' shows the command history; 'intest ?N' repeats command N from it\n\n"
		L"OPTIONS are as follows:\n"
	);

	CommandLine::declare_switch(PURGE_CLSW, L"purge", 1,
		L"delete any extraneous files from the intest workspace on disc");
	CommandLine::declare_boolean_switch(HISTORY_CLSW, L"history", 1,
		L"use command history", TRUE);
	CommandLine::declare_boolean_switch(COLOURS_CLSW, L"colours", 1,
		L"show discrepancies in red and green using terminal emulation", TRUE);
	CommandLine::declare_boolean_switch(VERBOSE_CLSW, L"verbose", 1,
		L"print out all shell commands issued", FALSE);
	CommandLine::declare_numerical_switch(THREADS_CLSW, L"threads", 1,
		L"use X independent threads to test");

@ The following structure encodes a set of instructions from the user (probably
from the command line) about what Intest should do on this run:

=
typedef struct intest_instructions {
	int colours_switch;
	int verbose_switch;
	int version_switch;
	int purge_switch;
	int history_switch;
	int crash_switch;
	int threads_available;
	struct recipe *compiling_recipe; /* not a user setting, but convenient for parsing */
	struct linked_list *search_path; /* of |test_source| */
	struct linked_list *to_do_list; /* of |action_item| */
	struct filename *implied_recipe_file;
	struct pathname *home;
	struct pathname *groups_folder;
	struct dictionary *singular_case_names;
} intest_instructions;

@<Initialise the arguments state@> =
	args.colours_switch = TRUE;
	args.verbose_switch = FALSE;
	args.version_switch = FALSE;
	args.purge_switch = FALSE;
	args.history_switch = TRUE;
	args.crash_switch = FALSE;
	args.compiling_recipe = NULL;
	args.search_path = NEW_LINKED_LIST(test_source);
	args.to_do_list = NEW_LINKED_LIST(action_item);
	args.threads_available = Platform::get_core_count();
	args.home = home;
	args.groups_folder = NULL;
	args.implied_recipe_file = intest_script;
	args.singular_case_names = Dictionaries::new(10, TRUE);

@h Actually reading the command line.
What will do is to divide the sequence of tokens on the command line into
"blocks". There are two sorts: "using" and "do" blocks. By default, the
parameters form a do block, unless |-using| is found, in which case
everything after that until a |-do| is found (if it is) counts as a
using block. For example,
= (text)
	alpha beta -using gamma -do delta epsilon
=
would be divided into the do block |alpha beta|, then the using block |gamma|,
then the do block |delta epsilon|.

@e NO_BLOCK_MODE from 0
@e USING_BLOCK_MODE
@e DO_BLOCK_MODE

=
void Instructions::read_instructions_into(intest_instructions *args,
	int from_arg_n, int to_arg_n, text_stream **argv, pathname *home) {
	int i, block_mode = NO_BLOCK_MODE, block_from = -1;
	for (i=from_arg_n; i<to_arg_n; i++) {
		text_stream *opt = argv[i];
		int next_block_mode = NO_BLOCK_MODE, next_block_from = -1;
		if (Str::eq(opt, I"-using")) { next_block_mode = USING_BLOCK_MODE; next_block_from = i+1; }
		else if (Str::eq(opt, I"-do")) { next_block_mode = DO_BLOCK_MODE; next_block_from = i+1; }
		else if (i == from_arg_n) { next_block_mode = DO_BLOCK_MODE; next_block_from = i; }
		if (next_block_mode != NO_BLOCK_MODE) {
			@<Complete block just finished, if any@>;
			block_mode = next_block_mode; block_from = next_block_from;
		}
	}
	@<Complete block just finished, if any@>;
}

@ Once the boundaries of a block are found, we hand it over to the relevant
authorities. The front end (only) of a do block is allowed to contain the
Foundation-defined switches, so we clear thpse out of the way first.

@<Complete block just finished, if any@> =
	switch (block_mode) {
		case USING_BLOCK_MODE:
			RecipeFiles::read_using_instructions(args, block_from, i, argv, home);
			args->implied_recipe_file = NULL;
			break;
		case DO_BLOCK_MODE: {
			int midway = Instructions::read_switches(args, block_from, i, argv);
			if (midway < i) {
				if (args->implied_recipe_file) {
					RecipeFiles::read(args->implied_recipe_file, args, NULL);
					args->implied_recipe_file = NULL;
				}
				Actions::read_do_instructions(args, midway, i, argv);
			}
			break;
		}
	}

@h Parsing Foundation-defined switches.
As noted above, not all commands are done via Foundation. The following
routine picks up any that are. If a do block contains:
= (text)
	-threads=4 -no-colours -help alpha beta
=
then this code will read and act on |-threads=4 -no-colours -help|, returning
an advanced start position for the do block, i.e., cutting it down to
just |alpha beta|.

=
int Instructions::read_switches(intest_instructions *args,
	int from_arg_n, int to_arg_n, text_stream **argv) {
	match_results mr = Regexp::create_mr();
	for (int i=from_arg_n; i<to_arg_n; i++) {
		text_stream *opt = argv[i];
		text_stream *arg = NULL; if (i+1 < to_arg_n) arg = argv[i+1];
		if (Regexp::match(&mr, opt, L"-+(%c*)")) {
			clf_reader_state crs;
			crs.state = (void *) args; crs.f = &Instructions::respond; crs.g = NULL;
			crs.subs = FALSE; crs.nrt = 0;
			int N = CommandLine::read_pair(&crs, mr.exp[0], arg);
			if (N > 0) { i += N - 1; }
			else { Regexp::dispose_of(&mr); return i; }
		} else { Regexp::dispose_of(&mr); return i; }
	}
	Regexp::dispose_of(&mr);
	return to_arg_n;
}

@ This routine handles the configuration switches registered with Foundation
back at the start of the section. (The built-in set, such as |-help|, is
automatically handled by Foundation's |CommandLine::read_pair| routine.)

=
void Instructions::respond(int id, int val, text_stream *arg, void *state) {
	intest_instructions *args = (intest_instructions *) state;
	switch (id) {
		case PURGE_CLSW: args->purge_switch = TRUE; return;
		case HISTORY_CLSW: args->history_switch = val; return;
		case COLOURS_CLSW: args->colours_switch = val; return;
		case VERBOSE_CLSW: args->verbose_switch = val; return;
		case THREADS_CLSW:
			if ((val < 1) || (val > MAX_THREADS))
				Errors::fatal("that number of threads is unsupported");
			args->threads_available = val;
			return;
	}
}
