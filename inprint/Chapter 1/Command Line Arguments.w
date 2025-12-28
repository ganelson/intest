[Configuration::] Command Line Arguments.

To parse the command line arguments with which inprint was called,
and to handle any errors it needs to issue.

@h Instructions.
The following structure exists just to hold what the user specified on the
command line: there will only ever be one of these.

=
typedef struct inprint_instructions {
	int subcommand; /* our main mode of operation: one of the |*_CLSUB| constants */
	int verbose_switch; /* |-verbose|: print a narrative of what's happening */
	int silent_switch; /* |-silent|: print nothing if all is well */

	struct inprint_build_settings build_settings;
	struct inprint_draw_settings draw_settings;
	struct pathname *temp_path_setting; /* project folder relative to cwd */
	struct filename *temp_file_setting; /* or, single file relative to cwd */
} inprint_instructions;

@h Reading the command line.
The dull work of this is done by the Foundation module: all we need to do is
to enumerate constants for the Inprint-specific command line switches, and
then declare them.

=
inprint_instructions Configuration::read(int argc, char **argv) {
	inprint_instructions args;
	@<Initialise the args@>;
	@<Declare the command-line switches specific to Inprint@>;
	args.subcommand = CommandLine::read(argc, argv, &args,
		&Configuration::switch, &Configuration::bareword);
	return args;
}

@<Initialise the args@> =
	args.subcommand = NO_CLSUB;
	args.verbose_switch = FALSE;
	args.silent_switch = FALSE;
	args.temp_path_setting = NULL;
	args.temp_file_setting = NULL;

	InprintBuild::initialise(&(args.build_settings));
	InprintDraw::initialise(&(args.draw_settings));

@ The CommandLine section of Foundation needs to be told what command-line
switches we want, other than the standard set (such as |-help|) which it
provides automatically.

@e VERBOSE_CLSW
@e SILENT_CLSW

@<Declare the command-line switches specific to Inprint@> =
	CommandLine::declare_heading(U"inprint: a tool for blueprints of file trees\n\n"
		U"Inprint is a small utility to make it more convenient to test programs\n"
		U"which read in a tree of files, and modify it or output another.\n"
		U"The textual form of such a tree is called a 'blueprint'.\n\n"
		U"Usage: inweb COMMAND [DETAILS]\n\n"
		U"where the DETAILS are different for each COMMAND.");

	CommandLine::resume_group(FOUNDATION_CLSG);
	CommandLine::declare_boolean_switch(VERBOSE_CLSW, U"verbose", 1,
		U"explain what inweb is doing", FALSE);
	CommandLine::declare_boolean_switch(SILENT_CLSW, U"silent", 1,
		U"print nothing unless errors occur", FALSE);
	CommandLine::end_group();

	InprintBuild::cli();
	InprintDraw::cli();

@ Foundation calls this on any |-switch| argument read:

=
void Configuration::switch(int id, int val, text_stream *arg, void *state) {
	inprint_instructions *args = (inprint_instructions *) state;
	if (InprintBuild::switch(args, id, val, arg)) return;
	if (InprintDraw::switch(args, id, val, arg)) return;
	switch (id) {
		/* Miscellaneous */
		case VERBOSE_CLSW: args->verbose_switch = val; break;
		case SILENT_CLSW: args->silent_switch = val; break;

		default: internal_error("unimplemented switch");
	}
}

@ Foundation calls this routine on any command-line argument which is neither a
switch, nor an argument for a switch.

=
void Configuration::bareword(int id, text_stream *opt, void *state) {
	int used = FALSE;
	inprint_instructions *args = (inprint_instructions *) state;
	if ((args->temp_path_setting == NULL) && (args->temp_file_setting == NULL)) {
		filename *putative = Filenames::from_text(opt);
		pathname *putative_path = Pathnames::from_text(opt);
		if (TextFiles::exists(putative)) {
			args->temp_file_setting = putative; used = TRUE;
		} else if (Directories::exists(putative_path)) {
			args->temp_path_setting = putative_path; used = TRUE;
		}
		if (used == FALSE) args->temp_file_setting = putative;
	} else Errors::fatal_with_text("superfluous argument: '%S'", opt);
}
