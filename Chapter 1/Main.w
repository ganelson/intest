[Main::] Main.

The top level, which decides what is to be done and then carries
this plan out.

@h Main routine.
This is basically simple. We work out what project the user wants us to
test; we look through the command line to configure things and read some
testing commands, and then we carry them out.

What makes it a little more elaborate is that Intest does unusual things
with its command line, preserving a command history, allowing substitution
of parameters and so on. It's almost a little shell language of its own.
This work of rewriting the command line is mostly done by a part of Intest
called the "historian", which manages the command history.

=
pathname *home_project = NULL;
pathname *installation = NULL;

int main(int argc, char **argv) {
	Basics::start();

	int ts_argc = 0; text_stream **ts_argv = NULL;

	@<Soak up the command line contents@>;
	@<Work out what the home project is@>;

	pathname *home = Pathnames::down(home_project, I"Tests");
	Log::set_debug_log_filename(Filenames::in(home, I"intest-debug-log.txt"));
	filename *script = NULL;
	@<Work out the default name for the test script@>;

	filename *history = Filenames::in(home, I"intest-history.txt");
	Historian::research(history, &ts_argc, &ts_argv);
	int write_up = FALSE;

	@<Read the now-final command line and act upon it@>;

	if (write_up) Historian::write_up(history);

	Basics::end();
	return (problem_count == 0)?0:1;
}

@ We will need to modify the command-line tokens, so we have to get them out
of their locale-encoded null-terminated C strings, in |argv[]|, and into
proper Unicode |text_stream| strings, in |ts_argv[]|.

Note that if the tester specifies nothing at all at the command line, we
invent |-help|. It follows that |ts_argc| will always be at least 2.

@<Soak up the command line contents@> =
	ts_argc = argc;
	if (argc == 1) ts_argc = 2;
	ts_argv = Memory::calloc(argc, sizeof(text_stream *), COMMAND_HISTORY_MREASON);
	for (int i=0; i<argc; i++) {
		char *p = argv[i];
		if ((p[0] == '-') && (p[1] == '-')) p++; /* allow a doubled-dash as equivalent to a single */
		ts_argv[i] = Str::new_from_locale_string(p);
	}
	if (argc == 1) ts_argv[1] = I"-help";

@ Intest was originally designed for testing Inform 7, so it defaults to
that as the project under test. Everybody else has to specify |-from P|,
where |P| is the project location, at the front of the command line. Note
that we remove those two tokens if we do find them.

(They are token numbers 1 and 2, not 0 and 1, because token 0 will be the
shell command used to invoke Intest. We simply ignore token 0.)

@<Work out what the home project is@> =
	if ((Str::eq(ts_argv[1], I"-from")) && (ts_argc >= 3)) {
		home_project = Pathnames::from_text(ts_argv[2]);
		ts_argc -= 2; ts_argv += 2;
	} else if (Str::get_first_char(ts_argv[1]) != '-') {
		home_project = Pathnames::from_text(ts_argv[1]);
		ts_argc--; ts_argv++;
	}

@ Every program to be tested has to provide a "script". It can be chosen at
the command line, but the default is to take the tested program's directory
leafname and add |.intest|. For example, if we're testing |magiczap|, then
the default is |magiczap.intest|.

@<Work out the default name for the test script@> =
	TEMPORARY_TEXT(sfn);
	WRITE_TO(sfn, "%S.intest", Pathnames::directory_name(Pathnames::up(home)));
	script = Filenames::in(home, sfn);
	DISCARD_TEXT(sfn);

@<Read the now-final command line and act upon it@> =
	intest_instructions args = ITCommandLine::read_instructions(ts_argc, ts_argv, home, script);

	if (args.version_switch) printf("%s\n", INTEST_BUILD);
	if (args.purge_switch) Tester::purge_all_work_areas(args.threads_available);
	if (args.verbose_switch) Shell::verbose();
	Differ::set_colour_usage(args.colours_switch);
	if (args.crash_switch) Errors::enter_debugger_mode();
	write_up = args.history_switch;
	installation = Pathnames::installation_path("INTEST_PATH", I"intest");
	if (args.verbose_switch) PRINT("Installation path is %p\n", installation);
	Globals::start();

	if (home_project) Actions::perform(STDOUT, &args);
