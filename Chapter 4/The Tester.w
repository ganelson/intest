[Tester::] The Tester.

To run a compiled recipe on a single test case.

@h Test interpreter.
To test is to interpret a recipe already compiled from Delia code into a
parse tree in memory.

Note that there are several different action types which can bring us here --
|-test|, |-show|, |-bless|, and so on -- and that the meaning of commands
in the recipe may depend on what we're trying to do with it.

The "work area" is a folder inside the Intest distribution containing files
we may need: we can read but not write it. The "thread work area", on the
other hand, is a private folder which no other thread has access to, so that
we can both read and write. In Delia code, the text |$WORK| expands to the
pathname of the thread work area.

The debugging log is split into multiple logs, one per thread, only if the
"tester" debugging log aspect is switched on. The mutex here means that
performance is greatly reduced if so.

=
int Tester::test(OUTPUT_STREAM, test_case *tc, int count, int thread_count, int action_type) {
	if (tc == NULL) internal_error("no test case");
	int passed = TRUE;
	if (splitting_logs) {
		CREATE_MUTEX(mutex);
		LOCK_MUTEX(mutex);
		DL = &(thread_slots[thread_count].split_log);
		@<Actually test@>;
		DL = NULL;
		UNLOCK_MUTEX(mutex);
	} else {
		@<Actually test@>;
	}
	return passed;
}

@<Actually test@> =
	pathname *Work_Area = Globals::to_pathname(I"workspace");
	int n = thread_count;
	if (n < 0) n = 0; /* if we're not multi-tasking, use thread 0's work area */
	pathname *Thread_Work_Area = Scheduler::work_area(n);
	pathname *Example_materials =
		Pathnames::subfolder(Thread_Work_Area, I"Example.materials");
	Pathnames::create_in_file_system(Example_materials);
	
	Tester::purge_work_area(n);
	@<Perform and report on the test@>;

@ The "brackets" here are used in the summary text; |[5]|, |(5)| and |-5-| are
all possible.

@<Perform and report on the test@> =
	TEMPORARY_TEXT(verdict); /* brief text summarising the outcome, e.g., "passed" */
	WRITE_TO(verdict, "passed");
	filename *damning_evidence = NULL;
	filename *match_fail1 = NULL, *match_fail2 = NULL;
	char left_bracket = '[', right_bracket = ']';
	@<Follow the test recipe@>;
	WRITE("%c%d%c %S %S\n", left_bracket, count, right_bracket, tc->test_case_name, verdict);
	if (match_fail1) @<Issue any necessary diff or bbdiff commands@>;
	if (damning_evidence) Extractor::cat(OUT, damning_evidence);
	tc->left_bracket = left_bracket;
	tc->right_bracket = right_bracket;
	DISCARD_TEXT(verdict);

@ Running with |-diff| or |-bbdiff| delegates the displaying of match errors
to those superior tools:

@<Issue any necessary diff or bbdiff commands@> =
	char *difftool = NULL;
	if (action_type == DIFF_ACTION) difftool = "diff";
	if (action_type == BBDIFF_ACTION) difftool = "bbdiff";
	if (difftool) {
		TEMPORARY_TEXT(COMMAND)
		WRITE_TO(COMMAND, "%s ", difftool);
		Shell::quote_file(COMMAND, match_fail1);
		Shell::quote_file(COMMAND, match_fail2);
		Shell::run(COMMAND);
		DISCARD_TEXT(COMMAND);
		damning_evidence = NULL;
	}

@ And now for the interpreter. Given a block of commands, we are either
executing them, or skipping them: we record that on a stack because blocks
can be nested. The entire recipe is considered as a block for this purpose,
and it's one that we are always executing.

@d MAX_IF_NESTING 10

@d CREATE_EXECUTION_CONTEXT
	int execution_state[MAX_IF_NESTING];
	int execution_state_sp = 0;

@d ENTER_EXECUTION_BLOCK(state) {
	if (execution_state_sp >= MAX_IF_NESTING) internal_error("ifs too deeply nested in recipe");
	else execution_state[execution_state_sp++] = state;
}

@d INVERT_EXECUTION_BLOCK {
	if (execution_state_sp <= 1) internal_error("ifs nested wrongly in recipe");
	execution_state[execution_state_sp-1] = (execution_state[execution_state_sp-1])?FALSE:TRUE;
}

@d EXIT_EXECUTION_BLOCK {
	if (execution_state_sp <= 1) internal_error("ifs nested wrongly in recipe");
	execution_state_sp--;
}

@<Follow the test recipe@> =
	LOGIF(TESTER, "Following test recipe %S on %S (action %d)\n",
		tc->test_recipe_name, tc->test_case_name, action_type);

	int hash_value_written = FALSE;
	dictionary *D = Dictionaries::new(10, TRUE);
	@<Populate the test dictionary@>;

	CREATE_EXECUTION_CONTEXT;
	ENTER_EXECUTION_BLOCK(TRUE); /* the block for the entire recipe */

	int line_count = 0;
	int no_match_commands = 0;
	int no_step_commands = 0;
	recipe *R = Delia::find(tc->test_recipe_name);
	if (R == NULL) {
		Str::clear(verdict);
		WRITE_TO(verdict, "no recipe called '%S' to test this with", tc->test_recipe_name);
		passed = FALSE;
	} else {
		int still_going = TRUE;
		recipe_line *L;
		LOOP_OVER_LINKED_LIST(L, recipe_line, R->lines)
			if (still_going) {
				@<Log the line@>;
				@<Interpret line@>;
			}
	}
	if ((passed) && (hash_value_written))
		Hasher::assign_to_case(tc, Dictionaries::get_text(D, I"HASHCODE"));
	Dictionaries::dispose_of(D);
	LOGIF(TESTER, "Recipe completed: %s: %S\n", passed?"pass":"fail", verdict);

@ It would be tempting to use intest's main variables dictionary here, but that
wouldn't be thread-safe, so each usage of this routine gets its own private
dictionary.

@<Populate the test dictionary@> =
	WRITE_TO(Dictionaries::create_text(D, I"CASE"), "%S", tc->test_case_name);
	WRITE_TO(Dictionaries::create_text(D, I"SCRIPT"), ""); /* set by the |extract| command, if used */
	WRITE_TO(Dictionaries::create_text(D, I"PATH"), "%p", tc->work_area);
	WRITE_TO(Dictionaries::create_text(D, I"WORK"), "%p", Thread_Work_Area);
	WRITE_TO(Dictionaries::create_text(D, I"HASHCODE"), ""); /* set by |hash| commands */
	WRITE_TO(Dictionaries::create_text(D, I"TYPE"), "%S", RecipeFiles::case_type_as_text(tc->test_type));

@<Log the line@> =
	line_count++;
	LOGIF(TESTER, "%d: ", line_count);
	for (int i=0; i<execution_state_sp; i++) LOGIF(TESTER, "%s ", execution_state[i]?"on":"off");
	LOGIF(TESTER, "| $L\n", L);

@<Interpret line@> =
	int running = TRUE;
	for (int i=0; i<execution_state_sp; i++) if (execution_state[i] == FALSE) running = FALSE;
	switch (L->command_used->rc_code) {
		case IF_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if a regular expression matches@>;
			break;
		case ELSE_RCOM:
			if (execution_state_sp <= 1) internal_error("else without if in recipe");
			INVERT_EXECUTION_BLOCK;
			break;
		case ENDIF_RCOM:
			if (execution_state_sp <= 1) internal_error("endif without if in recipe");
			EXIT_EXECUTION_BLOCK;
			break;
		case PASS_RCOM:
			if (running) {
				still_going = FALSE; passed = TRUE; Delia::dequote_first_token(verdict, L);
			}
			break;
		case FAIL_RCOM:
			if (running) {
				still_going = FALSE; passed = FALSE; Delia::dequote_first_token(verdict, L);
			}
			break;
		case OR_RCOM: break;
		default:
			if (running) @<Interpret an unconditional line@>;
			break;
	}

@<Enter an execution block if a regular expression matches@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	TEMPORARY_TEXT(A);
	TEMPORARY_TEXT(P);
	Tester::expand(A, first, D);
	Tester::expand(P, second, D);
	wchar_t P_C_string[1024];
	Str::copy_to_wide_string(P_C_string, P, 1024);
	match_results mr = Regexp::create_mr();
	ENTER_EXECUTION_BLOCK(Regexp::match(&mr, A, P_C_string));
	DISCARD_TEXT(A);
	DISCARD_TEXT(P);
	Regexp::dispose_of(&mr);

@<Interpret an unconditional line@> =
	switch (L->command_used->rc_code) {
		case STEP_RCOM:               @<Carry out a step@>; break;
		case DEBUGGER_RCOM:	          if (action_type == DEBUGGER_ACTION) @<Carry out a step@>; break;		
		case FAIL_STEP_RCOM:          @<Carry out a step@>; break;

		case SET_RCOM:                @<Set a local variable@>; break;

		case MATCH_TEXT_RCOM:         @<Carry out a match@>; break;
		case MATCH_BINARY_RCOM:       @<Carry out a match@>; break;
		case MATCH_FOLDER_RCOM:       @<Carry out a match@>; break;
		case MATCH_G_TRANSCRIPT_RCOM: @<Carry out a match@>; break;
		case MATCH_Z_TRANSCRIPT_RCOM: @<Carry out a match@>; break;
		case MATCH_PROBLEM_RCOM:      @<Carry out a match@>; break;

		case HASH_RCOM:               @<Carry out a hash@>; break;
		case EXTRACT_RCOM:            @<Make an extract@>; break;
		case EXISTS_RCOM:             @<Require existence of file@>; break;
		case COPY_RCOM:               @<Copy a file@>; break;
		case MKDIR_RCOM:              @<Make a directory@>; break;

		case SHOW_RCOM:               if (action_type == SHOW_ACTION) @<Show file@>; break;
		case SHOW_I6_RCOM:            if (action_type == SHOW_I6_ACTION) @<Show file@>; break;
		case SHOW_TRANSCRIPT_RCOM:    if (action_type == SHOW_TRANSCRIPT_ACTION) @<Show file@>; break;

		default: internal_error("unknown recipe command");
	}

@h Steps.
The |step| and |fail step| commands are essentially the same: expand the
tokens into a command, call the shell to run it, and require the return value
to be zero (for |step|) or non-zero (for |fail step|).

@<Carry out a step@> =
	if (action_type != CURSE_ACTION) {
		no_step_commands++;
		TEMPORARY_TEXT(COMMAND);
		recipe_token *T;
		LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens) {
			Tester::quote_expand(COMMAND, T, D);
			WRITE_TO(COMMAND, " ");
		}
		int rv = Shell::run(COMMAND);
		if (L->command_used->rc_code == FAIL_STEP_RCOM) {
			if (rv == 0) {
				Str::clear(verdict); WRITE_TO(verdict, "step %d should have failed but didn't", no_step_commands);
				passed = FALSE; still_going = FALSE;
				@<Or...@>;
			}
		} else {
			if (rv != 0) {
				Str::clear(verdict); WRITE_TO(verdict, "step %d failed to run", no_step_commands);
				passed = FALSE; still_going = FALSE;
				@<Or...@>;
			}
		}
		DISCARD_TEXT(COMMAND);
	}

@ If the next command is an |or|, then use its text rather than our bland
one in the event of failure.

@<Or...@> =
	linked_list_item *next_item = NEXT_ITEM_IN_LINKED_LIST(L_item, recipe_line);
	recipe_line *next_line = CONTENT_IN_ITEM(next_item, recipe_line);
	if ((next_line) &&
		(next_line->command_used->rc_code == OR_RCOM) &&
		(LinkedLists::len(next_line->recipe_tokens) > 0)) {
		Delia::dequote_first_token(verdict, next_line);
		recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, next_line->recipe_tokens);
		if (second) damning_evidence = Tester::extract_as_filename(second, D);
	}

@h Variables.
If the given value is a single word then we expand it as such, but otherwise
we use quote expansion on each token. This is important because if "options"
is set to, say, |frog $toad| before expansion, and the value of "toad" is,
say, "green amphibian", then we get |'frog' 'green amphibian'|. See the
documentation.

@<Set a local variable@> =
	recipe_token *first = FIRST_IN_LINKED_LIST(recipe_token, L->recipe_tokens);
	text_stream *name = first->token_text;
	TEMPORARY_TEXT(V);
	recipe_token *T;
	LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens)
		if (T != first) {
			if (LinkedLists::len(L->recipe_tokens) > 2)
				Tester::quote_expand(V, T, D);
			else
				Tester::expand(V, T, D);
		}
	Str::copy(Dictionaries::create_text(D, name), V);
	LOGIF(TESTER, "Variable %S set to <%S>\n", name, V);
	DISCARD_TEXT(V);

@h Matches.
In a match, two files are compared. We'll call the first file "actual" and the
second "ideal"; the idea is that the first has been produced by earlier steps,
while the second is a record of what it ought to come out as.

@<Carry out a match@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	filename *matching_actual = Tester::extract_as_filename(first, D);
	filename *matching_ideal = Tester::extract_as_filename(second, D);

	int exists = TextFiles::exists(matching_ideal);

	switch(action_type) {
		case BLESS_ACTION:
			if (exists) {
				Str::clear(verdict); WRITE_TO(verdict, "was already blessed: use -rebless to change");
				passed = FALSE; still_going = FALSE;
			} else @<Perform a blessing@>;
			break;
		case REBLESS_ACTION: @<Perform a blessing@>; break;
		case CURSE_ACTION: @<Perform a curse@>; break;
		case SHOW_ACTION:
		case TEST_ACTION:
		case DEBUGGER_ACTION:
		case DIFF_ACTION:
		case BBDIFF_ACTION:
			if (!exists) {
				Str::clear(verdict); WRITE_TO(verdict, "passed (but no blessed result exists to compare with)");
				LOGIF(TESTER, "Unable to find blessed file at %f\n", matching_ideal);
				left_bracket = '-'; right_bracket = '-';
			} else @<Perform a test match@>;
			break;
	}
	no_match_commands++;

@ To "bless" is to make the actual output also the ideal.

@<Perform a blessing@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "cp -p ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);
	Str::clear(verdict); WRITE_TO(verdict, "passed (blessing this transcript in future)");

@ To "curse" is to delete the ideal.

@<Perform a curse@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "rm ");
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);
	if (action_type == CURSE_ACTION) { Str::clear(verdict); WRITE_TO(verdict, "cursed (no test conducted)"); }

@ That just leaves the actual comparison. We support five different file formats
for these, three of which are highly specific to Inform 7.

@<Perform a test match@> =
	TEMPORARY_TEXT(DOT);
	WRITE_TO(DOT, "diff_output_%d.txt", no_match_commands);
	filename *DO = Filenames::in_folder(Thread_Work_Area, DOT);
	DISCARD_TEXT(DOT);
	int rv = 0;
	switch (L->command_used->rc_code) {
		case MATCH_TEXT_RCOM: @<Perform a plain text test match@>; break;
		case MATCH_BINARY_RCOM: @<Perform a binary test match@>; break;
		case MATCH_FOLDER_RCOM: @<Perform a folder match@>; break;
		case MATCH_G_TRANSCRIPT_RCOM: @<Perform a Glulxe transcript test match@>; break;
		case MATCH_Z_TRANSCRIPT_RCOM: @<Perform a Frotz transcript test match@>; break;
		case MATCH_PROBLEM_RCOM: @<Perform a problem test match@>; break;
		default: internal_error("unknown recipe command");
	}

	if (rv != 0) {
		passed = FALSE;
		Str::clear(verdict); WRITE_TO(verdict, "failed to match");
		still_going = FALSE; match_fail1 = matching_actual; match_fail2 = matching_ideal;
		if (action_type != SHOW_ACTION) Extractor::cat(OUT, DO);
		@<Or...@>;
	}

@<Perform a plain text test match@> =
	TEMPORARY_TEXT(COMMAND);
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	skein *A = Skeins::from_plain_text(matching_actual);
	skein *I = Skeins::from_plain_text(matching_ideal);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND);

@<Perform a plain text test match using diff@> =
	TEMPORARY_TEXT(COMMAND);
	WRITE_TO(COMMAND, "diff ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::redirect(COMMAND, DO);
	rv = Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@<Perform a binary test match@> =
	TEMPORARY_TEXT(COMMAND);
	WRITE_TO(COMMAND, "cmp -b ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::redirect(COMMAND, DO);
	rv = Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@<Perform a folder match@> =
	TEMPORARY_TEXT(COMMAND);
	WRITE_TO(COMMAND, "diff -arq -x '.DS_Store' ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::redirect(COMMAND, DO);
	rv = Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@<Perform a Frotz transcript test match@> =
	TEMPORARY_TEXT(COMMAND);
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_Z_transcript(matching_actual, cle);
	skein *I = Skeins::from_Z_transcript(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND);

@<Perform a Glulxe transcript test match@> =
	TEMPORARY_TEXT(COMMAND);
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_G_transcript(matching_actual, cle);
	skein *I = Skeins::from_G_transcript(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND);

@<Perform a problem test match@> =
	TEMPORARY_TEXT(COMMAND);
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_i7_problems(matching_actual, cle);
	skein *I = Skeins::from_i7_problems(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, TRUE) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND);

@h Miscellaneous other commands.
The |extract| command only makes sense for Inform 7 test cases.

@<Make an extract@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	filename *i7_here = Tester::extract_as_filename(first, D);
	int test_me_exists = Tester::extract_source_to_file(i7_here, tc);
	filename *script_file = NULL;
	if (TextFiles::exists(tc->commands_location)) {
		script_file = tc->commands_location;
	} else if (test_me_exists) {
		TEMPORARY_TEXT(T);
		Tester::expand(T, second, D);
		if (Str::eq(T, I"Z"))
			script_file = Filenames::in_folder(Work_Area, I"ZT.sol");
		else if (Str::eq(T, I"G"))
			script_file = Filenames::in_folder(Work_Area, I"GT.sol");
		else
			Errors::fatal_with_text("extract can only be to Z or G, not %S", T);
		DISCARD_TEXT(T);
	} else {
		TEMPORARY_TEXT(T);
		Tester::expand(T, second, D);
		if (Str::eq(T, I"Z"))
			script_file = Filenames::in_folder(Work_Area, I"ZQ.sol");
		else if (Str::eq(T, I"G"))
			script_file = Filenames::in_folder(Work_Area, I"GQ.sol");
		else
			Errors::fatal_with_text("extract can only be to Z or G, not %S", T);
		DISCARD_TEXT(T);
	}
	WRITE_TO(Dictionaries::get_text(D, I"SCRIPT"), "%f", script_file);

@ The |exists| command requires a file to exist on disc.

@<Require existence of file@> =
	if (action_type == TEST_ACTION) {
		recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
		filename *putative = Tester::extract_as_filename(first, D);
		if (TextFiles::exists(putative) == FALSE) {
			Str::clear(verdict); WRITE_TO(verdict, "file doesn't exist: %f", putative);
			still_going = FALSE; passed = FALSE;
			@<Or...@>;
		}
	}

@ The |show| and |show i6| commands both use this:

@<Show file@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	filename *putative = Tester::extract_as_filename(first, D);
	if (TextFiles::exists(putative)) {
		Extractor::cat(OUT, putative);
		still_going = FALSE;
		passed = TRUE;
	} else {
		Str::clear(verdict); WRITE_TO(verdict, "can't show file, as it doesn't exist: %f", putative);
		still_going = FALSE;
		@<Or...@>;
	}

@ The |hash| command hashes the first-named file, writing the resulting
checksum to the second-named file, and also remembering its value.

@<Carry out a hash@> =
	if (action_type == TEST_ACTION) {
		recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
		recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
		filename *to_hash = Tester::extract_as_filename(first, D);
		filename *checksum = Tester::extract_as_filename(second, D);
		text_stream *hash_utility = Globals::get(I"hash_utility");
		if (Str::len(hash_utility) > 0) {
			TEMPORARY_TEXT(COMMAND)
			Shell::plain_text(COMMAND, hash_utility);
			Shell::plain(COMMAND, " ");
			Shell::quote_file(COMMAND, to_hash);
			Shell::redirect(COMMAND, checksum);
			Shell::run(COMMAND);
			DISCARD_TEXT(COMMAND)
			text_stream *hash_value = Dictionaries::get_text(D, I"HASHCODE");
			Hasher::read_hash(hash_value, checksum);
			hash_value_written = TRUE;
			if (Hasher::compare_hashes(tc, hash_value)) {
				still_going = FALSE;
				passed = TRUE;
				Str::clear(verdict); WRITE_TO(verdict, "passed (ending test early on hash value grounds)");
				@<Or...@>;
				left_bracket = '(';
				right_bracket = ')';
			}
		}
	}

@ The |copy| command copies the first-named file to the second filename.

@<Copy a file@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	filename *from = Tester::extract_as_filename(first, D);
	filename *to = Tester::extract_as_filename(second, D);
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "cp -p ");
	Shell::quote_file(COMMAND, from);
	Shell::quote_file(COMMAND, to);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@ The |mkdir| command ensures that a named directory exists.

@<Make a directory@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	pathname *to_make = Tester::extract_as_pathname(first, D);
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "mkdir -p ");
	Shell::quote_path(COMMAND, to_make);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@ =
int Tester::extract_source_to_file(filename *F, test_case *tc) {
	if (tc) tc->test_me_detected = FALSE;
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, F, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write to file", F);
	if (tc)
		Extractor::run(NULL, TO, tc, tc->test_location, tc->format_reference,
			tc->letter_reference, SOURCE_ACTION, NULL);
	STREAM_CLOSE(TO);
	return (tc)?(tc->test_me_detected):FALSE;
}

@h Purging.
Tests can do quite a variety of things to the thread work area, so we'll
clean it out to factory-fresh contents.

=
void Tester::purge_all_work_areas(int n) {
	for (int i=0; i<n; i++) Tester::purge_work_area(i);
}

void Tester::purge_work_area(int n) {
	pathname *Thread_Work_Area = Scheduler::work_area(n);
	pathname *Example_materials =
		Pathnames::subfolder(Thread_Work_Area, I"Example.materials");
	pathname *Example_inform =
		Pathnames::subfolder(Thread_Work_Area, I"Example.inform");
	@<Remove text files from the work area@>;
	@<Remove miscellaneous files from the materials@>;
	@<Clean out the project, too@>;
}

@<Remove text files from the work area@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "cd ");
	Shell::quote_path(COMMAND, Thread_Work_Area);
	WRITE_TO(COMMAND, "; rm -f *.txt");
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@<Remove miscellaneous files from the materials@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "find ");
	Shell::quote_path(COMMAND, Example_materials);
	WRITE_TO(COMMAND, " -mindepth 1 -delete");
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@<Clean out the project, too@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "cd ");
	Shell::quote_path(COMMAND, Example_inform);
	WRITE_TO(COMMAND, "; rm -f Build/*.*; rm -f Index/Details/*.*;  rm -f Index/*.*");
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND);

@ When we want a filename, we don't want it quoted.

=
filename *Tester::extract_as_filename(recipe_token *T, dictionary *D) {
	filename *F = NULL;
	TEMPORARY_TEXT(A);
	Tester::expand(A, T, D);
	if ((Str::get_first_char(A) == SHELL_QUOTE_CHARACTER) &&
		(Str::get_last_char(A) == SHELL_QUOTE_CHARACTER)) {
		int L = Str::len(A);
		TEMPORARY_TEXT(B);
		for (int i=1; i<L-1; i++)
			PUT_TO(B, Str::get_at(A, i));
		F = Filenames::from_text(B);
		DISCARD_TEXT(B);
	} else {
		F = Filenames::from_text(A);
	}
	DISCARD_TEXT(A);
	return F;
}
pathname *Tester::extract_as_pathname(recipe_token *T, dictionary *D) {
	pathname *P = NULL;
	TEMPORARY_TEXT(A);
	Tester::expand(A, T, D);
	if ((Str::get_first_char(A) == SHELL_QUOTE_CHARACTER) &&
		(Str::get_last_char(A) == SHELL_QUOTE_CHARACTER)) {
		int L = Str::len(A);
		TEMPORARY_TEXT(B);
		for (int i=1; i<L-1; i++)
			PUT_TO(B, Str::get_at(A, i));
		P = Pathnames::from_text(B);
		DISCARD_TEXT(B);
	} else {
		P = Pathnames::from_text(A);
	}
	DISCARD_TEXT(A);
	return P;
}

@h Token expansion.
At run-time, the contents of a token usually need to be expanded before they
can be used; the result will depend on what test case is being run through
the recipe, which is why this isn't done at compile time.

Expansion is the process of replacing variables like |$PATH| with their
values. We have two versions of this. Simple expansion, as follows, does
just that and no more. Note that the |$$| notation is meaningful only for
filenames in the settings file, not for local variables.

=
void Tester::expand(OUTPUT_STREAM, recipe_token *T, dictionary *D) {
	text_stream *original = T->token_text;
	LOGIF(VARIABLES, "From %S\n", original);
	TEMPORARY_TEXT(unsubstituted);
	Str::copy(unsubstituted, original);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, unsubstituted, L"(%c*)$$(%i+)(%c*)")) {
		Str::copy(unsubstituted, mr.exp[0]);
		filename *F = Globals::to_filename(mr.exp[1]);
		if (F) {
			WRITE_TO(unsubstituted, "%f", F);
		} else {
			Errors::with_text("no such setting as %S", mr.exp[1]);
			WRITE_TO(unsubstituted, "(novalue)");
		}
		WRITE_TO(unsubstituted, "%S", mr.exp[2]);
	}
	while (Regexp::match(&mr, unsubstituted, L"(%c*)$(%i+)(%c*)")) {
		Str::copy(unsubstituted, mr.exp[0]);
		text_stream *dv = Dictionaries::get_text(D, mr.exp[1]);
		if (dv) WRITE_TO(unsubstituted, "%S", dv);
		else {
			Errors::with_text("no such variable as %S", mr.exp[1]);
			WRITE_TO(unsubstituted, "(novalue)");
		}
		WRITE_TO(unsubstituted, "%S", mr.exp[2]);
	}
	WRITE("%S", unsubstituted);
	LOGIF(VARIABLES, "To %S\n", unsubstituted);
	Regexp::dispose_of(&mr);
}

@ Quote expansion is similar, but treats the text as something which needs
to end up in quotation marks so that the shell will treat it as a single
lexical token.

=
void Tester::quote_expand(OUTPUT_STREAM, recipe_token *T, dictionary *D) {
	if (T == NULL) return;
	TEMPORARY_TEXT(unquoted);

	Tester::expand(unquoted, T, D);

	if (T->token_indirects_to_file) @<Expand token from file@>
	else if (T->token_quoted == NOT_APPLICABLE) @<Expand token from text@>
	else @<Apply quotation marks as needed@>;

	DISCARD_TEXT(unquoted);
}

@ Note the manoeuvre to avoid trouble with shell redirection: |>'Fred'| is
a legal redirection, but |'>Fred'| is not; and |2>&1| joins standard errors
to standard output, but |2>'&1'| sends errors to a file literally called |&1|.

@<Apply quotation marks as needed@> =
	TEMPORARY_TEXT(quoted);
	wchar_t c = Str::get_first_char(unquoted);
	int n = T->token_quoted;
	if ((c == '>') || (c == '<')) { PUT(c); Str::delete_first_character(unquoted); }
	else if ((Characters::isdigit(c)) && (Str::get_at(unquoted, 1) == '>')) {
		PUT(c); PUT('>');
		Str::delete_first_character(unquoted);
		Str::delete_first_character(unquoted);
		if (Str::get_at(unquoted, 0) == '&') n = TRUE;
	}
	if (n != FALSE) Shell::plain_text(quoted, unquoted);
	else Shell::quote_text(quoted, unquoted);
	WRITE("%S", quoted);
	DISCARD_TEXT(quoted);

@ This is what happens to backticked tokens: they're retokenised and each is
individually quote-expanded.

@<Expand token from text@> =
	linked_list *L = NEW_LINKED_LIST(recipe_token);
	Delia::tokenise(L, unquoted);
	recipe_token *ET;
	int N = 0;
	LOOP_OVER_LINKED_LIST(ET, recipe_token, L) {
		if (N++ > 0) WRITE(" ");
		Tester::quote_expand(OUT, ET, D);
	}

@ Expanding from a file is similar, but more work; we need to read the file
in, one line at a time. (Each line is expanded.)

@<Expand token from file@> =
	filename *F = Filenames::from_text(unquoted);
	token_expand_state T;
	T.expand_to = OUT;
	T.expand_from = D;
	TextFiles::read(F, FALSE, "can't open file of recipe line arguments",
		TRUE, &Tester::read_tokens, NULL, &T);

@ ...which makes use of:

=
typedef struct token_expand_state {
	struct text_stream *expand_to;
	struct dictionary *expand_from;
} token_expand_state;

void Tester::read_tokens(text_stream *line_text, text_file_position *tfp, void *vTES) {
	linked_list *L = NEW_LINKED_LIST(recipe_token);
	Delia::tokenise(L, line_text);
	token_expand_state *T = (token_expand_state *) vTES;
	recipe_token *RT;
	int N = 0;
	LOOP_OVER_LINKED_LIST(RT, recipe_token, L) {
		if (N++ > 0) WRITE_TO(T->expand_to, " ");
		Tester::quote_expand(T->expand_to, RT, T->expand_from);
	}
}
