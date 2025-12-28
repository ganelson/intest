[Main::] Program Control.

The top level, which is little more than a demarcation between subcommands.

@ Every program using //foundation// must define this:

@d PROGRAM_NAME "inprint"

@ We do as little as possible here, and delegate everything to
the subcommands.

=
int main(int argc, char **argv) {
	@<Initialise inprint@>;
	inprint_instructions args = Configuration::read(argc, argv);
	@<Make some global settings@>;
	if (no_inprint_errors == 0) @<Delegate to the subcommand@>;
	@<Shut inprint down@>;
}

@<Initialise inprint@> =
	Foundation::start(argc, argv);

@ We keep global settings to a minimum. Note that the installation path can
only be set after the command-line switches are read, since they can change it.

= (early code)
pathname *path_to_inprint = NULL; /* where we are installed */
int no_inprint_errors = 0;
int verbose_mode = FALSE, silent_mode = FALSE;

@<Make some global settings@> =
	verbose_mode = args.verbose_switch;
	silent_mode = args.silent_switch;
	path_to_inprint = Pathnames::installation_path("PRINT_PATH", I"inprint");
	if (verbose_mode) {
		PRINT("Installation path is %p\n", path_to_inprint);
		Locales::write_locales(STDOUT);
	}
	pathname *M = Pathnames::path_to_inweb_materials();
	Pathnames::set_path_to_LP_resources(M);

@<Delegate to the subcommand@> =
	switch (args.subcommand) {
		case NO_CLSUB:
			if (argc <= 1)
				PRINT("inprint: a tool for blueprints of file trees. See 'inprint help' for more.\n");
			break;
		case BUILD_CLSUB: InprintBuild::run(&args); break;
		case DRAW_CLSUB:  InprintDraw::run(&args); break;
	}

@<Shut inprint down@> =
	Foundation::end();
	return (no_inprint_errors == 0)?0:1;
