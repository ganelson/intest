[Basics::] Basics.

Some fundamental definitions.

@h Build identity.
This notation tangles out to the current build number as specified in the
contents section of this web.

@d PROGRAM_NAME "intest"
@d INTEST_BUILD "intest [[Version Number]]"

@h Starting and stopping Foundation.
Like all the other Inform tools, this one is built on top of a module of
standard library routines called Foundation. When Intest starts and ends,
the following are called:

=
void Basics::start(int argc, char **argv) {
	Foundation::start(argc, argv);
	ArchModule::start();
	@<Declare new memory allocation reasons@>;
	@<Declare new debugging log aspects@>;
	@<Declare new writers and loggers@>;
}

void Basics::end(void) {
	Foundation::end();
}

@h Simple allocations.
Not all of our memory will be claimed in the form of structures: now and then
we need to use the equivalent of traditional `malloc` and `calloc` routines.

@e TURN_STORAGE_MREASON
@e COMMAND_HISTORY_MREASON

@<Declare new memory allocation reasons@> =
	Memory::reason_name(TURN_STORAGE_MREASON, "skein turn storage");
	Memory::reason_name(COMMAND_HISTORY_MREASON, "command history storage");

@h Debugging log.

@e VARIABLES_DA
@e INSTRUCTIONS_DA
@e DIFFER_DA
@e HASHER_DA
@e TESTER_DA

@<Declare new debugging log aspects@> =
	Log::declare_aspect(VARIABLES_DA, U"variables", FALSE, FALSE);
	Log::declare_aspect(INSTRUCTIONS_DA, U"instructions", FALSE, FALSE);
	Log::declare_aspect(DIFFER_DA, U"differ", FALSE, FALSE);
	Log::declare_aspect(HASHER_DA, U"hasher", FALSE, FALSE);
	Log::declare_aspect(TESTER_DA, U"tester", FALSE, FALSE);

@h Writers and loggers.
This enables the `%k` and `$L` format notations in `WRITE` and `LOG`
respectively.

@<Declare new writers and loggers@> =
	Writers::register_writer('k', &Skeins::write_node_label);
	Writers::register_logger('L', &Delia::log_line);
