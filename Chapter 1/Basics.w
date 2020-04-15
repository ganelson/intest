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
void Basics::start(void) {
	Foundation::start();
	@<Declare new memory allocation reasons@>;
	@<Declare new debugging log aspects@>;
	@<Declare new writers and loggers@>;
}

void Basics::end(void) {
	Foundation::end();
}

@h Simple allocations.
Not all of our memory will be claimed in the form of structures: now and then
we need to use the equivalent of traditional |malloc| and |calloc| routines.

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
	Log::declare_aspect(VARIABLES_DA, L"variables", FALSE, FALSE);
	Log::declare_aspect(INSTRUCTIONS_DA, L"instructions", FALSE, FALSE);
	Log::declare_aspect(DIFFER_DA, L"differ", FALSE, FALSE);
	Log::declare_aspect(HASHER_DA, L"hasher", FALSE, FALSE);
	Log::declare_aspect(TESTER_DA, L"tester", FALSE, FALSE);

@h Writers and loggers.
This enables the |%k| and |$L| format notations in |WRITE| and |LOG|
respectively.

@<Declare new writers and loggers@> =
	Writers::register_writer('k', &Skeins::write_node_label);
	Writers::register_logger('L', &Delia::log_line);

@h Setting up the memory manager.
We need to itemise the structures we'll want to allocate:

@e action_item_MT
@e test_case_MT
@e search_path_item_MT
@e skein_MT
@e edit_MT
@e diff_results_MT
@e test_MT
@e historic_moment_MT
@e recipe_MT
@e recipe_line_MT
@e recipe_token_MT

@ =
ALLOCATE_INDIVIDUALLY(action_item)
ALLOCATE_INDIVIDUALLY(test_case)
ALLOCATE_INDIVIDUALLY(search_path_item)
ALLOCATE_INDIVIDUALLY(skein)
ALLOCATE_INDIVIDUALLY(edit)
ALLOCATE_INDIVIDUALLY(diff_results)
ALLOCATE_INDIVIDUALLY(test)
ALLOCATE_INDIVIDUALLY(historic_moment)
ALLOCATE_INDIVIDUALLY(recipe)
ALLOCATE_INDIVIDUALLY(recipe_line)
ALLOCATE_INDIVIDUALLY(recipe_token)
