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
int Tester::test(OUTPUT_STREAM, test_case *tc, int count, int thread_count,
	int action_type, text_stream *action_details) {
	if (tc == NULL) internal_error(((char *) tc) /* "no test case" */);
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
	int n = thread_count;
	if (n < 0) n = 0; /* if we're not multi-tasking, use thread 0's work area */
	pathname *Thread_Work_Area = Scheduler::work_area(n);
	pathname *Example_materials =
		Pathnames::down(Thread_Work_Area, I"Example.materials");
	Pathnames::create_in_file_system(Example_materials);
	
	Tester::purge_work_area(n);
	@<Perform and report on the test@>;

@ The "brackets" here are used in the summary text; |[5]|, |(5)| and |-5-| are
all possible.

@<Perform and report on the test@> =
	int compare_as_HTML = FALSE;
	if (tc->HTML_report) compare_as_HTML = TRUE;
	TEMPORARY_TEXT(verdict) /* brief text summarising the outcome, e.g., "passed" */
	WRITE_TO(verdict, "passed");
	filename *damning_evidence = NULL, *mismatched_file = NULL;
	filename *match_fail1 = NULL, *match_fail2 = NULL;
	char left_bracket = '[', right_bracket = ']';
	@<Follow the test recipe@>;
	WRITE("%c%d%c %S %S\n", left_bracket, count, right_bracket, tc->test_case_name, verdict);
	if (match_fail1) @<Issue any necessary diff or bbdiff commands@>;
	if (damning_evidence) Extractor::cat(OUT, damning_evidence);
	tc->left_bracket = left_bracket;
	tc->right_bracket = right_bracket;
	if (tc->HTML_report) @<Write an HTML-format report on this test@>;
	DISCARD_TEXT(verdict)

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
		DISCARD_TEXT(COMMAND)
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
	LOGIF(TESTER, "Following test recipe %S on %S (aka '%S') (action %d)\n",
		tc->test_recipe_name, tc->test_case_name, tc->test_case_title, action_type);
	if (Tester::running_verbosely()) {
		WRITE_TO(STDOUT, "Following test recipe %S on %S (aka '%S') (action %d)\n",
			tc->test_recipe_name, tc->test_case_name, tc->test_case_title, action_type);
		WRITE_TO(STDOUT, "Global variables:\n");
		linked_list *L = Globals::all();
		text_stream *name;
		LOOP_OVER_LINKED_LIST(name, text_stream, L) {
			WRITE_TO(STDOUT, "      $$%S = %S\n", name, Globals::get(name));
		}
		WRITE_TO(STDOUT, "Local variables at start:\n");
	}

	int hash_value_written = FALSE;
	dictionary *D = Dictionaries::new(10, TRUE);

	CREATE_EXECUTION_CONTEXT;
	ENTER_EXECUTION_BLOCK(TRUE); /* the block for the entire recipe */

	int line_count = 0;
	int no_match_commands = 0;
	int no_step_commands = 0;
	TEMPORARY_TEXT(recipe_name)
	TEMPORARY_TEXT(stipulation)
	WRITE_TO(recipe_name, "%S", tc->test_recipe_name);
	int stipulating = FALSE;
	for (int i=0; i<Str::len(tc->test_recipe_name); i++) {
		inchar32_t c = Str::get_at(tc->test_recipe_name, i);
		if (c == ':') {
			if (stipulating == FALSE) {
				Str::put_at(recipe_name, i, ']');
				Str::put_at(recipe_name, i+1, 0);
				stipulating = TRUE;
			} else {
				@<Add a stipulation@>;
				Str::clear(stipulation);
			}
		} else if (c == ']') {
			break;
		} else if (stipulating) {
			PUT_TO(stipulation, c);
		}
	}
	@<Add a stipulation@>;
	DISCARD_TEXT(recipe_name)
	DISCARD_TEXT(stipulation)
	@<Populate the test dictionary@>;

	if (Tester::running_verbosely()) {
		WRITE_TO(STDOUT, "Recipe execution:\n");
	}

	recipe *R = Delia::find(recipe_name);
	if (R == NULL) {
		Str::clear(verdict);
		WRITE_TO(verdict, "no recipe called '%S' to test this with", recipe_name);
		passed = FALSE;
	} else {
		int still_going = TRUE;
		if (action_type == SHOW_ACTION) {
			linked_list *allowed = Tester::spot_show_target(R, action_details);
			if (allowed) {
				Str::clear(verdict);
				WRITE_TO(verdict,
					"test runs with recipe '%S' which cannot produce the show "
					"target '-show-%S'",
					recipe_name, action_details);
				if (LinkedLists::len(allowed) == 0) WRITE_TO(verdict, " (or any other)");
				else {
					WRITE_TO(verdict, ", only ");
					text_stream *X;
					int c = 0;
					LOOP_OVER_LINKED_LIST(X, text_stream, allowed) {
						if (c++ > 0) WRITE_TO(verdict, ", ");
						if (Str::len(X) > 0) WRITE_TO(verdict, "-show-%S", X);
						else WRITE_TO(verdict, "-show");
					}
				}
				passed = FALSE;
				still_going = FALSE;
			}
		}
		if (still_going) {
			int show_made = FALSE, last_step_passed = NOT_APPLICABLE;
			recipe_line *L;
			LOOP_OVER_LINKED_LIST(L, recipe_line, R->lines)
				if (still_going) {
					@<Log the line@>;
					@<Interpret line@>;
				}
			if ((action_type == SHOW_ACTION) && (show_made == FALSE)) {
				passed = FALSE;
				Str::clear(verdict);
				WRITE_TO(verdict,
					"test completed without reaching a '-show-%S' command",
					action_details);
			}
		}
	}
	if ((passed) && (hash_value_written))
		Hasher::assign_to_case(tc, Dictionaries::get_text(D, I"HASHCODE"));
	Dictionaries::dispose_of(D);
	LOGIF(TESTER, "Recipe completed: %s: %S\n", passed?"pass":"fail", verdict);

@<Add a stipulation@> =
	if (Str::len(stipulation) > 0) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, stipulation, U" *(%C+) *= *(%c*?) *")) {
			text_stream *key = mr.exp[0];
			text_stream *value = mr.exp[1];
			Tester::populate(D, key, value);
		} else {
			Str::clear(verdict);
			WRITE_TO(verdict, "stipulation '%S' made no sense for test '%S'",
				stipulation, tc->test_recipe_name);
			passed = FALSE;
		}
		Regexp::dispose_of(&mr);
	}

@ It would be tempting to use intest's main variables dictionary here, but that
wouldn't be thread-safe, so each usage of this routine gets its own private
dictionary.

@<Populate the test dictionary@> =
	Tester::populate(D, I"CASE", tc->test_case_name);
	Tester::populate(D, I"TITLE", tc->test_case_title);
	Tester::populate_path(D, I"PATH", tc->work_area);
	pathname *P = Filenames::up(tc->test_location);
	while ((P) && (Str::eq(Pathnames::directory_name(P), I"Extensions") == FALSE))
		P = Pathnames::up(P);
	if (P) Tester::populate_path(D, I"NEST", Pathnames::up(P));
	Tester::populate_path(D, I"WORK", Thread_Work_Area);
	Tester::populate(D, I"TYPE", RecipeFiles::case_type_as_text(tc->test_type));
	for (int i=0; i<tc->no_kv_pairs; i++) {
		TEMPORARY_TEXT(key)
		LOOP_THROUGH_TEXT(pos, tc->keys[i])
			PUT_TO(key, Characters::toupper(Str::get(pos)));
		Tester::populate(D, key, tc->values[i]);
		DISCARD_TEXT(key)
	}

@<Log the line@> =
	line_count++;
	LOGIF(TESTER, "%d: ", line_count);
	for (int i=0; i<execution_state_sp; i++) LOGIF(TESTER, "%s ", execution_state[i]?"on":"off");
	LOGIF(TESTER, "| $L\n", L);
	if (Tester::running_verbosely()) {
		int running = TRUE;
		for (int i=0; i<execution_state_sp; i++) if (execution_state[i] == FALSE) running = FALSE;
		if (running) {
			WRITE_TO(STDOUT, "%04d: ", line_count);
			Delia::log_line(STDOUT, L);
			WRITE_TO(STDOUT, "\n");
		}
	}

@<Interpret line@> =
	int running = TRUE;
	for (int i=0; i<execution_state_sp; i++) if (execution_state[i] == FALSE) running = FALSE;
	switch (L->command_used->rc_code) {
		case IF_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if a regular expression matches@>;
			break;
		case IFDEF_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if a variable exists@>;
			break;
		case IFNDEF_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if a variable does not exist@>;
			break;
		case IFPASS_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if the last command worked@>;
			break;
		case IFFAIL_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if the last command did not work@>;
			break;
		case IF_SHOWING_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if running this -show action@>;
			break;
		case IF_COMPATIBLE_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if this VM is compatible@>;
			break;
		case IF_EXISTS_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if a file exists@>;
			break;
		case IF_FORMAT_VALID_RCOM:
			if (running == FALSE) ENTER_EXECUTION_BLOCK(FALSE)
			else @<Enter an execution block if this VM exists@>;
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
				still_going = FALSE; passed = FALSE; 
				Str::clear(verdict);
				Delia::dequote_first_token(verdict, L);
				recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
				if (second) damning_evidence = Tester::extract_as_filename(second, D);
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
	TEMPORARY_TEXT(A)
	TEMPORARY_TEXT(P)
	Tester::expand(A, first, D);
	Tester::expand(P, second, D);
	inchar32_t P_C_string[1024];
	Str::copy_to_wide_string(P_C_string, P, 1024);
	match_results mr = Regexp::create_mr();
	ENTER_EXECUTION_BLOCK(Regexp::match(&mr, A, P_C_string));
	DISCARD_TEXT(A)
	DISCARD_TEXT(P)
	if (mr.no_matched_texts >= 1)
		Tester::populate(D, I"SUBEXPRESSION1", Str::duplicate(mr.exp[0]));
	if (mr.no_matched_texts >= 2)
		Tester::populate(D, I"SUBEXPRESSION2", Str::duplicate(mr.exp[1]));
	if (mr.no_matched_texts >= 3)
		Tester::populate(D, I"SUBEXPRESSION3", Str::duplicate(mr.exp[2]));
	if (mr.no_matched_texts >= 4)
		Tester::populate(D, I"SUBEXPRESSION4", Str::duplicate(mr.exp[3]));
	Regexp::dispose_of(&mr);

@<Enter an execution block if a variable exists@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	text_stream *key = first->token_text;
	int enter = FALSE;
	if ((Globals::exists(key)) || (Dictionaries::find(D, key) != NULL)) enter = TRUE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if a variable does not exist@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	text_stream *key = first->token_text;
	int enter = TRUE;
	if ((Globals::exists(key)) || (Dictionaries::find(D, key) != NULL)) enter = FALSE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if the last command worked@> =
	int enter = FALSE;
	if (last_step_passed == TRUE) enter = TRUE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if the last command did not work@> =
	int enter = FALSE;
	if (last_step_passed == FALSE) enter = TRUE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if running this -show action@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	text_stream *item = first->token_text;
	int enter = FALSE;
	if ((action_type == SHOW_ACTION) &&
		(Str::eq_insensitive(action_details, item))) enter = TRUE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if this VM is compatible@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	TEMPORARY_TEXT(A)
	TEMPORARY_TEXT(B)
	Tester::expand(A, first, D);
	Tester::expand(B, second, D);
	target_vm *VM = TargetVMs::find(A);
	if (VM == NULL)
		Errors::with_text("malformed compilation format: '%S'", A);
	compatibility_specification *cs = Compatibility::from_text(B);
	if (cs == NULL)
		Errors::with_text("malformed compatibility text: '%S'", B);
	int enter = FALSE;
	if ((cs) && (VM) && (Compatibility::test(cs, VM))) enter = TRUE;
	DISCARD_TEXT(A)
	DISCARD_TEXT(B)
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if this VM exists@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	TEMPORARY_TEXT(A)
	Tester::expand(A, first, D);
	target_vm *VM = TargetVMs::find(A);
	int enter = FALSE;
	if (VM) enter = TRUE;
	ENTER_EXECUTION_BLOCK(enter);

@<Enter an execution block if a file exists@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	filename *putative = Tester::extract_as_filename(first, D);
	ENTER_EXECUTION_BLOCK(TextFiles::exists(putative));

@<Interpret an unconditional line@> =
	last_step_passed = NOT_APPLICABLE;
	switch (L->command_used->rc_code) {
		case STEP_RCOM:               @<Carry out a step@>; break;
		case DEBUGGER_RCOM:	          if (action_type == DEBUGGER_ACTION) @<Carry out a step@>; break;		
		case FAIL_STEP_RCOM:          @<Carry out a step@>; break;

		case SET_RCOM:                @<Set a local variable@>; break;
		case DEFAULT_RCOM:            @<Set a local variable@>; break;

		case MATCH_TEXT_RCOM:         @<Carry out a match@>; break;
		case MATCH_PLATFORM_TEXT_RCOM:@<Carry out a match@>; break;
		case MATCH_BINARY_RCOM:       @<Carry out a match@>; break;
		case MATCH_FOLDER_RCOM:       @<Carry out a match@>; break;
		case MATCH_G_TRANSCRIPT_RCOM: @<Carry out a match@>; break;
		case MATCH_I6_TRANSCRIPT_RCOM:@<Carry out a match@>; break;
		case MATCH_Z_TRANSCRIPT_RCOM: @<Carry out a match@>; break;
		case MATCH_PROBLEM_RCOM:      @<Carry out a match@>; break;

		case HASH_RCOM:               @<Carry out a hash@>; break;
		case EXTRACT_RCOM:            @<Make an extract@>; break;
		case EXISTS_RCOM:             @<Require existence of file@>; break;
		case COPY_RCOM:               @<Copy a file@>; break;
		case MKDIR_RCOM:              @<Make a directory@>; break;
		case REMOVE_RCOM:             @<Remove a file@>; break;

		case SHOW_RCOM:               if (action_type == SHOW_ACTION) @<Show file@>; break;

		default: internal_error("unknown recipe command");
	}

@h Steps.
The |step| and |fail step| commands are essentially the same: expand the
tokens into a command, call the shell to run it, and require the return value
to be zero (for |step|) or non-zero (for |fail step|).

@<Carry out a step@> =
	if (action_type != CURSE_ACTION) {
		no_step_commands++;
		TEMPORARY_TEXT(COMMAND)
		recipe_token *T;
		LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens) {
			Tester::quote_expand(COMMAND, T, D, FALSE);
			WRITE_TO(COMMAND, " ");
		}
		int rv = Shell::run(COMMAND);
		if (L->command_used->rc_code == FAIL_STEP_RCOM) {
			if (rv == 0) {
				Str::clear(verdict);
				WRITE_TO(verdict, "step %d should have failed but didn't", no_step_commands);
				passed = FALSE; still_going = FALSE;
				@<Or@>;
				if (last_step_passed == FALSE) last_step_passed = TRUE;
			}
		} else {
			if (rv != 0) {
				Str::clear(verdict);
				WRITE_TO(verdict, "step %d failed to run", no_step_commands);
				passed = FALSE; still_going = FALSE;
				@<Or@>;
			}
		}
		DISCARD_TEXT(COMMAND)
	}

@ If the next command is an |or|, then use its text rather than our bland
one in the event of failure.

@<Or@> =
	linked_list_item *next_item = NEXT_ITEM_IN_LINKED_LIST(L_item, recipe_line);
	recipe_line *next_line = CONTENT_IN_ITEM(next_item, recipe_line);
	if ((next_line) &&
		(next_line->command_used->rc_code == OR_RCOM) &&
		(LinkedLists::len(next_line->recipe_tokens) > 0)) {
		Delia::dequote_first_token(verdict, next_line);
		recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, next_line->recipe_tokens);
		if (second) damning_evidence = Tester::extract_as_filename(second, D);
	} else if ((next_line) &&
		((next_line->command_used->rc_code == IFPASS_RCOM) ||
			(next_line->command_used->rc_code == IFFAIL_RCOM))) {
		still_going = TRUE; last_step_passed = FALSE;
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
	TEMPORARY_TEXT(V)
	recipe_token *T;
	LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens)
		if (T != first) {
			if (LinkedLists::len(L->recipe_tokens) > 2)
				Tester::quote_expand(V, T, D, FALSE);
			else
				Tester::expand(V, T, D);
		}
	if (L->command_used->rc_code == DEFAULT_RCOM) {
		Tester::populate_default(D, name, V);
	} else {
		Tester::populate(D, name, V);
	}
	DISCARD_TEXT(V)

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
				Str::clear(verdict); 
				WRITE_TO(verdict, "was already blessed: use -rebless to change");
				passed = FALSE; still_going = FALSE;
			} else @<Perform a blessing@>;
			break;
		case REBLESS_ACTION: @<Perform a blessing@>; break;
		case CURSE_ACTION: @<Perform a curse@>; break;
		case SHOW_ACTION:
		case TEST_ACTION:
		case LIST_ACTION:
		case DEBUGGER_ACTION:
		case DIFF_ACTION:
		case BBDIFF_ACTION:
			if (!exists) {
				Str::clear(verdict);
				WRITE_TO(verdict, "passed (but no blessed result exists to compare with)");
				LOGIF(TESTER, "Unable to find blessed file at %f\n", matching_ideal);
				left_bracket = '-'; right_bracket = '-';
			} else @<Perform a test match@>;
			break;
	}
	no_match_commands++;

@ To "bless" is to make the actual output also the ideal.

@<Perform a blessing@> =
	BinaryFiles::copy(matching_actual, matching_ideal, TRUE);
	Str::clear(verdict); WRITE_TO(verdict, "passed (blessing this transcript in future)");

@ To "curse" is to delete the ideal.

@<Perform a curse@> =
	BinaryFiles::delete(matching_ideal);
	if (action_type == CURSE_ACTION) {
		Str::clear(verdict); WRITE_TO(verdict, "cursed (no test conducted)");
	}

@ That just leaves the actual comparison. We support five different file formats
for these, three of which are highly specific to Inform 7.

@<Perform a test match@> =
	TEMPORARY_TEXT(DOT)
	WRITE_TO(DOT, "diff_output_%d.txt", no_match_commands);
	filename *DO = Filenames::in(Thread_Work_Area, DOT);
	DISCARD_TEXT(DOT)
	int rv = 0;
	switch (L->command_used->rc_code) {
		case MATCH_TEXT_RCOM: @<Perform a plain text test match@>; break;
		case MATCH_PLATFORM_TEXT_RCOM: @<Perform a platform text test match@>; break;
		case MATCH_BINARY_RCOM: @<Perform a binary test match@>; break;
		case MATCH_FOLDER_RCOM: @<Perform a folder match@>; break;
		case MATCH_G_TRANSCRIPT_RCOM: @<Perform a Glulxe transcript test match@>; break;
		case MATCH_I6_TRANSCRIPT_RCOM: @<Perform an I6 transcript test match@>; break;
		case MATCH_Z_TRANSCRIPT_RCOM: @<Perform a Frotz transcript test match@>; break;
		case MATCH_PROBLEM_RCOM: @<Perform a problem test match@>; break;
		default: internal_error("unknown recipe command");
	}

	if (rv != 0) {
		passed = FALSE;
		Str::clear(verdict); WRITE_TO(verdict, "failed to match");
		still_going = FALSE; match_fail1 = matching_actual; match_fail2 = matching_ideal;
		if (action_type != SHOW_ACTION) {
			if (tc->HTML_report == NULL) Extractor::cat(OUT, DO);
			mismatched_file = DO;
		}
		@<Or@>;
	}

@<Perform a plain text test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	skein *A = Skeins::from_plain_text(matching_actual);
	skein *I = Skeins::from_plain_text(matching_ideal);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE, FALSE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@<Perform a platform text test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	skein *A = Skeins::from_plain_text(matching_actual);
	skein *I = Skeins::from_plain_text(matching_ideal);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE, TRUE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@<Perform a binary test match@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "cmp -b ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::redirect(COMMAND, DO);
	rv = Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)

@<Perform a folder match@> =
	TEMPORARY_TEXT(COMMAND)
	WRITE_TO(COMMAND, "diff -arq -x '.DS_Store' ");
	Shell::quote_file(COMMAND, matching_actual);
	Shell::quote_file(COMMAND, matching_ideal);
	Shell::redirect(COMMAND, DO);
	rv = Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)

@<Perform a Frotz transcript test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_Z_transcript(matching_actual, cle);
	skein *I = Skeins::from_Z_transcript(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE, FALSE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@<Perform a Glulxe transcript test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_G_transcript(matching_actual, cle);
	skein *I = Skeins::from_G_transcript(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE, FALSE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@<Perform an I6 transcript test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	skein *A = Skeins::from_i6_console_output(matching_actual);
	skein *I = Skeins::from_i6_console_output(matching_ideal);
	rv = 0;
	if (Skeins::compare(TO, A, I, FALSE, TRUE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@<Perform a problem test match@> =
	TEMPORARY_TEXT(COMMAND)
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, DO, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", DO);
	int cle = tc->command_line_echoing_detected;
	skein *A = Skeins::from_i7_problems(matching_actual, cle);
	skein *I = Skeins::from_i7_problems(matching_ideal, cle);
	rv = 0;
	if (Skeins::compare(TO, A, I, TRUE, FALSE, compare_as_HTML) > 0) rv = 1;
	Skeins::dispose_of(A);
	Skeins::dispose_of(I);
	STREAM_CLOSE(TO);
	DISCARD_TEXT(COMMAND)

@h Miscellaneous other commands.
The |extract| command only makes sense for Inform 7 test cases.

@<Make an extract@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	filename *i7_here = Tester::extract_as_filename(first, D);
	int test_me_exists = Tester::extract_source_to_file(i7_here, tc);
	filename *script_file = NULL;
	pathname *Solutions_Area = Globals::to_pathname(I"solutions");
	if (TextFiles::exists(tc->commands_location)) {
		script_file = tc->commands_location;
	} else if (test_me_exists) {
		TEMPORARY_TEXT(T)
		Tester::expand(T, second, D);
		if (Str::eq(T, I"Z"))
			script_file = Filenames::in(Solutions_Area, I"ZT.sol");
		else if (Str::eq(T, I"G"))
			script_file = Filenames::in(Solutions_Area, I"GT.sol");
		else
			Errors::fatal_with_text("extract can only be to Z or G, not %S", T);
		DISCARD_TEXT(T)
	} else {
		TEMPORARY_TEXT(T)
		Tester::expand(T, second, D);
		if (Str::eq(T, I"Z"))
			script_file = Filenames::in(Solutions_Area, I"ZQ.sol");
		else if (Str::eq(T, I"G"))
			script_file = Filenames::in(Solutions_Area, I"GQ.sol");
		else
			Errors::fatal_with_text("extract can only be to Z or G, not %S", T);
		DISCARD_TEXT(T)
	}
	if (script_file) Tester::populate_file(D, I"SCRIPT", script_file);

@ The |exists| command requires a file to exist on disc.

@<Require existence of file@> =
	if (action_type == TEST_ACTION) {
		recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
		filename *putative = Tester::extract_as_filename(first, D);
		if (TextFiles::exists(putative) == FALSE) {
			Str::clear(verdict); WRITE_TO(verdict, "file doesn't exist: %f", putative);
			still_going = FALSE; passed = FALSE;
			@<Or@>;
		}
	}

@ The |show| command has an optional second token:

@<Show file@> =
	recipe_token *what_token = NULL;
	recipe_token *file_token = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	if (LinkedLists::len(L->recipe_tokens) == 2) {
		what_token = file_token;
		file_token = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	}
	text_stream *what_to_show = Str::new();
	if (what_token) Tester::expand(what_to_show, what_token, D);
	filename *putative = Tester::extract_as_filename(file_token, D);
	
	if (Str::eq_insensitive(action_details, what_to_show)) {
		if (TextFiles::exists(putative)) {
			Extractor::cat(OUT, putative);
			still_going = FALSE;
			passed = TRUE;
			show_made = TRUE;
		} else {
			Str::clear(verdict);
			WRITE_TO(verdict, "can't show file, as it doesn't exist: %f", putative);
			still_going = FALSE;
			@<Or@>;
		}
	} else {
		if (Tester::running_verbosely()) {
			WRITE_TO(STDOUT, "      not showing because seeking '%S' not '%S'\n",
				action_details, what_to_show);
		}
	}

@ The |hash| command hashes the first-named file, writing the resulting
checksum to the second-named file, and also remembering its value.

@<Carry out a hash@> =
	if (action_type == TEST_ACTION) {
		recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
		filename *to_hash = Tester::extract_as_filename(first, D);
		TEMPORARY_TEXT(hash)
		BinaryFiles::md5(hash, to_hash, NULL);
		Tester::populate(D, I"HASHCODE", hash);
		hash_value_written = TRUE;
		if (Hasher::compare_hashes(tc, hash)) {
			still_going = FALSE;
			passed = TRUE;
			Str::clear(verdict);
			WRITE_TO(verdict, "passed (ending test early on hash value grounds)");
			@<Or@>;
			left_bracket = '(';
			right_bracket = ')';
		}
		DISCARD_TEXT(hash)
	}

@ The |copy| command copies the first-named file to the second filename.

@<Copy a file@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	filename *from = Tester::extract_as_filename(first, D);
	filename *to = Tester::extract_as_filename(second, D);
	BinaryFiles::copy(from, to, TRUE);

@ The |mkdir| command ensures that a named directory exists.

@<Make a directory@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	pathname *to_make = Tester::extract_as_pathname(first, D);
	Pathnames::create_in_file_system(to_make);

@ |remove| deletes a file:

@<Remove a file@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	filename *to_delete = Tester::extract_as_filename(first, D);
	BinaryFiles::delete(to_delete);

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
		Pathnames::down(Thread_Work_Area, I"Example.materials");
	pathname *Example_inform =
		Pathnames::down(Thread_Work_Area, I"Example.inform");
	@<Remove text files from the work area@>;
	@<Remove miscellaneous files from the materials@>;
	@<Clean out the project, too@>;
}

@<Remove text files from the work area@> =
	Directories::delete_contents(Thread_Work_Area, I".txt");

@<Remove miscellaneous files from the materials@> =
	Directories::delete_contents_recursively(Example_materials, NULL);

@<Clean out the project, too@> =
	pathname *P = Pathnames::down(Example_inform, I"Build");
	Directories::delete_contents(P, NULL);
	P = Pathnames::down(Example_inform, I"Details");
	Directories::delete_contents(P, NULL);
	P = Pathnames::down(Example_inform, I"Index");
	Directories::delete_contents(P, NULL);

@ When we want a filename, we don't want it quoted.

=
filename *Tester::extract_as_filename(recipe_token *T, dictionary *D) {
	filename *F = NULL;
	TEMPORARY_TEXT(A)
	Tester::expand(A, T, D);
	if ((Str::get_first_char(A) == DELIA_QUOTE_CHARACTER) &&
		(Str::get_last_char(A) == DELIA_QUOTE_CHARACTER)) {
		int L = Str::len(A);
		TEMPORARY_TEXT(B)
		for (int i=1; i<L-1; i++)
			PUT_TO(B, Str::get_at(A, i));
		F = Filenames::from_text(B);
		DISCARD_TEXT(B)
	} else {
		F = Filenames::from_text(A);
	}
	DISCARD_TEXT(A)
	return F;
}
pathname *Tester::extract_as_pathname(recipe_token *T, dictionary *D) {
	pathname *P = NULL;
	TEMPORARY_TEXT(A)
	Tester::expand(A, T, D);
	if ((Str::get_first_char(A) == DELIA_QUOTE_CHARACTER) &&
		(Str::get_last_char(A) == DELIA_QUOTE_CHARACTER)) {
		int L = Str::len(A);
		TEMPORARY_TEXT(B)
		for (int i=1; i<L-1; i++)
			PUT_TO(B, Str::get_at(A, i));
		P = Pathnames::from_text(B);
		DISCARD_TEXT(B)
	} else {
		P = Pathnames::from_text(A);
	}
	DISCARD_TEXT(A)
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
	TEMPORARY_TEXT(unsubstituted)
	Str::copy(unsubstituted, original);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, unsubstituted, U"(%c*)$$(%i+)(%c*)")) {
		Str::copy(unsubstituted, mr.exp[0]);
		filename *F = Globals::to_filename(mr.exp[1]);
		if (F) {
			WRITE_TO(unsubstituted, "%f", F);
		}
		WRITE_TO(unsubstituted, "%S", mr.exp[2]);
	}
	while (Regexp::match(&mr, unsubstituted, U"(%c*)$(%i+)(%c*)")) {
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
	DISCARD_TEXT(unsubstituted)
	Regexp::dispose_of(&mr);
}

@ Quote expansion is similar, but treats the text as something which needs
to end up in quotation marks so that the shell will treat it as a single
lexical token.

=
void Tester::quote_expand(OUTPUT_STREAM, recipe_token *T, dictionary *D, int raw) {
	if (T == NULL) return;
	
	if (Str::eq(T->token_text, I";")) { WRITE(";"); return; }
	
	TEMPORARY_TEXT(unquoted)
	if (raw) WRITE_TO(unquoted, "%S", T->token_text);
	else Tester::expand(unquoted, T, D);

	if (T->token_indirects_to_file) @<Expand token from file@>
	else if (T->token_indirects_to_hash) @<Expand token from hash@>
	else if (T->token_quoted == NOT_APPLICABLE) @<Expand token from text@>
	else @<Apply quotation marks as needed@>;

	DISCARD_TEXT(unquoted)
}

@ Note the manoeuvre to avoid trouble with shell redirection: |>'Fred'| is
a legal redirection, but |'>Fred'| is not; and |2>&1| joins standard errors
to standard output, but |2>'&1'| sends errors to a file literally called |&1|.

@<Apply quotation marks as needed@> =
	TEMPORARY_TEXT(quoted)
	inchar32_t c = Str::get_first_char(unquoted);
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
	DISCARD_TEXT(quoted)

@ This is what happens to backticked tokens: they're retokenised and each is
individually quote-expanded.

@<Expand token from text@> =
	linked_list *L = NEW_LINKED_LIST(recipe_token);
	Delia::tokenise(L, unquoted);
	recipe_token *ET;
	int N = 0;
	LOOP_OVER_LINKED_LIST(ET, recipe_token, L) {
		if (N++ > 0) WRITE(" ");
		Tester::quote_expand(OUT, ET, D, FALSE);
	}

@ Expanding from a file is similar, but more work; we need to read the file
in, one line at a time. (Each line is expanded.)

@<Expand token from file@> =
	int raw_flag = FALSE;
	filename *F;
	if (Str::get_first_char(unquoted) == '`') {
		TEMPORARY_TEXT(unticked)
		Str::copy(unticked, unquoted);
		Str::delete_first_character(unticked);
		F = Filenames::from_text(unticked);
		DISCARD_TEXT(unticked)
		raw_flag = TRUE;
	} else {
		F = Filenames::from_text(unquoted);
	}
	token_expand_state T;
	T.expand_to = OUT;
	T.expand_from = D;
	T.raw = raw_flag;
	TextFiles::read(F, FALSE, "can't open file of recipe line arguments",
		TRUE, &Tester::read_tokens, NULL, &T);

@ ...which makes use of:

=
typedef struct token_expand_state {
	struct text_stream *expand_to;
	struct dictionary *expand_from;
	int raw;
} token_expand_state;

void Tester::read_tokens(text_stream *line_text, text_file_position *tfp, void *vTES) {
	linked_list *L = NEW_LINKED_LIST(recipe_token);
	Delia::tokenise(L, line_text);
	token_expand_state *T = (token_expand_state *) vTES;
	recipe_token *RT;
	int N = 0;
	LOOP_OVER_LINKED_LIST(RT, recipe_token, L) {
		if (N++ > 0) WRITE_TO(T->expand_to, " ");
		Tester::quote_expand(T->expand_to, RT, T->expand_from, T->raw);
	}
}

@<Expand token from hash@> =
	int z = NOT_APPLICABLE;
	TEMPORARY_TEXT(name)
	if (Str::begins_with_wide_string(unquoted, U"zmachine:")) {
		Str::substr(name, Str::at(unquoted, 9), Str::end(unquoted)); z = TRUE;
	} else if (Str::begins_with_wide_string(unquoted, U"glulx:")) {
		Str::substr(name, Str::at(unquoted, 6), Str::end(unquoted)); z = FALSE;
	} else {
		WRITE_TO(name, "%S", unquoted);
	}
	filename *F = Filenames::from_text(name);
	switch (z) {
		case TRUE: BinaryFiles::md5(OUT, F, Tester::mask_Z); break;
		case FALSE: BinaryFiles::md5(OUT, F, Tester::mask_G); break;
		case NOT_APPLICABLE: BinaryFiles::md5(OUT, F, NULL); break;
	}
	DISCARD_TEXT(name)

@ The following functions are convenient for masking off bytes which we
expect to alter in any story file for the Z-machine or Glulx virtual machines:

=
int Tester::mask_Z(uint64_t pos) {
	if ((pos >= 18) && (pos < 24)) return TRUE; /* Serial number */
	if ((pos >= 28) && (pos < 30)) return TRUE; /* Checksum */
	if ((pos >= 60) && (pos < 64)) return TRUE; /* Inform 6 version */
	return FALSE;
}
int Tester::mask_G(uint64_t pos) {
	if ((pos >= 32) && (pos < 36)) return TRUE; /* Checksum */
	if ((pos >= 44) && (pos < 48)) return TRUE; /* Inform 6 version */
	if ((pos >= 54) && (pos < 60)) return TRUE; /* Serial number */
	return FALSE;
}

@h Spotting show targets.
This is quite slow and memory-profligate, which really doesn't matter. If
|target| is something shown by at least one command in the recipe, return
|NULL|; otherwise, release a linked list of the different targets which
are allowed.

=
linked_list *Tester::spot_show_target(recipe *R, text_stream *target) {
	recipe_line *L;
	linked_list *allowed = NEW_LINKED_LIST(text_stream);
	LOOP_OVER_LINKED_LIST(L, recipe_line, R->lines)
		if (L->command_used->rc_code == SHOW_RCOM) {
			text_stream *offered = Str::new();
			if (LinkedLists::len(L->recipe_tokens) == 2) {
				recipe_token *first =
					ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
				offered = first->token_text;
			}
			if (Str::eq_insensitive(offered, target)) return NULL;
			int known = FALSE;
			text_stream *X;
			LOOP_OVER_LINKED_LIST(X, text_stream, allowed)
				if (Str::eq_insensitive(X, offered))
					known = TRUE;
			if (known == FALSE)
				ADD_TO_LINKED_LIST(offered, text_stream, allowed);
		}
	return allowed;
}

@h HTML reportage.

@<Write an HTML-format report on this test@> =
	text_stream *OUT = tc->HTML_report;
	HTML_OPEN("tr");
	HTML_OPEN("td");
	if (passed) {
		if (action_type == TEST_ACTION) WRITE("&#x2705;");
		else WRITE("&#x2692;&#xFE0F;");
	} else WRITE("&#x274C;");
	HTML_CLOSE("td");
	HTML_OPEN("td");
	WRITE("%S", tc->test_case_name);
	if ((Str::len(tc->test_case_title) > 0) && (Str::ne(tc->test_case_title, tc->test_case_name)))
	WRITE(" (aka <em>%S</em>)", tc->test_case_title);
	HTML_CLOSE("td");
	HTML_OPEN("td");
	if (passed) {
		if (action_type == TEST_ACTION) WRITE("passed");
		else WRITE("done");
	} else WRITE("%S", verdict);
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	if (damning_evidence) {
		HTML_OPEN("tr");
		HTML_OPEN("td");
		HTML_CLOSE("td");
		HTML_OPEN_WITH("td", "colspan=\"2\"");
		HTML_OPEN("pre");
		int I = Streams::get_indentation(tc->HTML_report);
		Streams::set_indentation(tc->HTML_report, 0);
		Extractor::cat(tc->HTML_report, damning_evidence);
		Streams::set_indentation(tc->HTML_report, I);
		HTML_CLOSE("pre");		
		HTML_CLOSE("td");
		HTML_CLOSE("tr");
	}
	if (mismatched_file) {
		HTML_OPEN("tr");
		HTML_OPEN("td");
		HTML_CLOSE("td");
		HTML_OPEN_WITH("td", "colspan=\"2\"");
		HTML_OPEN_WITH("div", "class=\"skeinreport\"");
		int I = Streams::get_indentation(tc->HTML_report);
		Streams::set_indentation(tc->HTML_report, 0);
		Extractor::cat(tc->HTML_report, mismatched_file);
		Streams::set_indentation(tc->HTML_report, I);
		HTML_CLOSE("div");
		HTML_CLOSE("td");
		HTML_CLOSE("tr");
	}

@h Verbosity.
This is just for the sake of good output in |-verbose| mode:

=
int tester_verbose = FALSE;
void Tester::verbose(void) {
	tester_verbose = TRUE;
}
int Tester::running_verbosely(void) {
	return tester_verbose;
}
void Tester::populate(dictionary *D, text_stream *key, text_stream *value) {
	if (tester_verbose) WRITE_TO(STDOUT, "      $%S <--- %S\n", key, value);
	text_stream *T = Dictionaries::create_text(D, key);
	Str::clear(T);
	WRITE_TO(T, "%S", value);
	LOGIF(TESTER, "Variable %S set to <%S>\n", key, value);
}
void Tester::populate_path(dictionary *D, text_stream *key, pathname *P) {
	TEMPORARY_TEXT(value)
	WRITE_TO(value, "%p", P);
	Tester::populate(D, key, value);
	DISCARD_TEXT(value)
}
void Tester::populate_file(dictionary *D, text_stream *key, filename *F) {
	TEMPORARY_TEXT(value)
	WRITE_TO(value, "%f", F);
	Tester::populate(D, key, value);
	DISCARD_TEXT(value)
}
void Tester::populate_default(dictionary *D, text_stream *key, text_stream *value) {
	if (Dictionaries::find(D, key) == NULL)
		Tester::populate(D, key, value);
}
