[Historian::] The Historian.

To preserve a recent command history on disc.

@h History storage.
Recall that the history file records two things: past commands, such as |?2|,
stored in memory thus. The "epoch" is a number representing when this was;
for |?2|, it would be 2.

=
typedef struct historic_moment {
	int epoch;
	struct linked_list *token_list; /* of |text_stream| */
	CLASS_DEFINITION
} historic_moment;

@ =
int present_epoch = 1;
historic_moment *present_moment = NULL;

void Historian::create_present_moment(int argc, text_stream **argv) {
	if (argc > 0) {
		historic_moment *hm = CREATE(historic_moment);
		hm->epoch = present_epoch;
		hm->token_list = NEW_LINKED_LIST(text_stream);
		for (int c = 1; c<argc; c++) {
			text_stream *tok = Str::duplicate(argv[c]);
			ADD_TO_LINKED_LIST(tok, text_stream, hm->token_list);
		}
		present_moment = hm;
	}
}

@ ...and preset cases, such as |1|, stored as follows. The Historian is
notified of any failed tests by the Tester.

@d MAX_PRESET_CASES 99

=
int no_preset_cases = 0;
text_stream *preset_cases[MAX_PRESET_CASES + 1];

void Historian::notify_failure_count(int f) {
	no_preset_cases = f;
}

void Historian::notify_failure(int f, text_stream *p) {
	if (f <= MAX_PRESET_CASES) preset_cases[f] = Str::duplicate(p);
}

@h Research.
The historian runs in two phases. "Research" involves reading the history
file in, then performing substitution on the command. "Writing up" involves
writing the updated history file back again. One happens at the start of
Intest's run, the other at the end.

=
void Historian::research(filename *H, int *argc, text_stream ***argv) {
	int display_mode = FALSE;
	int epoch_to_repeat = -1;
	int expands = FALSE;
	@<Detect a ? or ?N request@>;
	Historian::read_history_file(H, display_mode);
	@<Complete a ? request@>;
	@<Complete a ?N request@>;
	@<Substitute preset case numbers@>;
	Historian::create_present_moment(*argc, *argv);
	if (expands) { PRINT("Expanded to: "); Historian::write_command(STDOUT, present_moment); }
}

@<Detect a ? or ?N request@> =
	if (*argc == 2) {
		text_stream *first_word = (*argv)[1];
		if (Str::get_at(first_word, 0) == '?') {
			if (Str::len(first_word) == 1) display_mode = TRUE;
			else epoch_to_repeat = Str::atoi(first_word, 1);
		}
	}

@<Complete a ? request@> =
	if (display_mode) {
		if (no_preset_cases > 0)
			for (int f = 0; f < no_preset_cases; f++) {
				PRINT("%d = %S", f+1, preset_cases[f]);
				if (f < no_preset_cases-1) PRINT("; ");
				else PRINT("\n");
			}
		*argc = 1;
		return;
	}

@<Complete a ?N request@> =
	historic_moment *to_repeat = NULL;
	if (*argc == 1) to_repeat = present_moment;
	else if (epoch_to_repeat != -1) {
		historic_moment *hm;
		LOOP_OVER(hm, historic_moment)
			if (hm->epoch == epoch_to_repeat)
				to_repeat = hm;
		if (to_repeat == NULL)
			Errors::fatal("no previous command with that number (try '?')");
	}
	if (to_repeat) {
		PRINT("Repeating: "); Historian::write_command(STDOUT, to_repeat);
		int c = 0;
		text_stream *tok;
		LOOP_OVER_LINKED_LIST(tok, text_stream, to_repeat->token_list) c++;
		*argv = Memory::calloc(c+1, sizeof(text_stream *), COMMAND_HISTORY_MREASON);
		*argc = c+1;
		c = 0; (*argv)[c++] = Str::new_from_ISO_string("intest");
		LOOP_OVER_LINKED_LIST(tok, text_stream, to_repeat->token_list)
			(*argv)[c++] = tok;
		return;
	}

@<Substitute preset case numbers@> =
	match_results mr = Regexp::create_mr();
	for (int i=1; i<*argc; i++)
		if (Regexp::match(&mr, (*argv)[i], U"%d+"))
			expands = TRUE;
	if (expands) {
		text_stream **new_argv =
			Memory::calloc(*argc, sizeof(text_stream *), COMMAND_HISTORY_MREASON);
		for (int i=0; i<*argc; i++) {
			text_stream *p = (*argv)[i];
			if ((i>0) && (Regexp::match(&mr, p, U"%d+"))) {
				int f = Str::atoi(p, 0);
				if ((f > 0) && (f <= no_preset_cases))
					new_argv[i] = preset_cases[f-1];
				else
					Errors::fatal_with_text("no test case of that number (try '?'): %S", p);
			} else new_argv[i] = p;
		}
		*argv = new_argv;
	}
	Regexp::dispose_of(&mr);

@h Reading history.

=
void Historian::read_history_file(filename *H, int display_mode) {
	TextFiles::read(H, FALSE, NULL, FALSE, &Historian::read, NULL, &display_mode);
}
void Historian::read(text_stream *line_text, text_file_position *tfp, void *dmp) {
	int display_mode = *((int *) dmp);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U"%?(%d+). (%c*)")) {
		TEMPORARY_TEXT(epoch_text)
		TEMPORARY_TEXT(command_text)
		Str::copy(epoch_text, mr.exp[0]);
		Str::copy(command_text, mr.exp[1]);

		historic_moment *hm = CREATE(historic_moment);
		hm->epoch = Str::atoi(epoch_text, 0);
		if (hm->epoch >= present_epoch) present_epoch = hm->epoch + 1;
		hm->token_list = NEW_LINKED_LIST(text_stream);
		while (Regexp::match(&mr, command_text, U"(%C+) *(%c*)")) {
			text_stream *tok = Str::duplicate(mr.exp[0]);
			ADD_TO_LINKED_LIST(tok, text_stream, hm->token_list);
			Str::copy(command_text, mr.exp[1]);
		}
		present_moment = hm;
		if (display_mode) Historian::write_command(STDOUT, hm);
		DISCARD_TEXT(epoch_text)
		DISCARD_TEXT(command_text)
	}
	if (Regexp::match(&mr, line_text, U"(%d+) = *(%c*)"))
		if (no_preset_cases < MAX_PRESET_CASES)
			preset_cases[no_preset_cases++] = Str::duplicate(mr.exp[1]);
	Regexp::dispose_of(&mr);
}

@h Writing history.

@d MAX_HISTORICAL_RECORD 20

=
void Historian::write_up(filename *H) {
	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, H, UTF8_ENC) == FALSE) return;
	int recorded_time = NUMBER_CREATED(historic_moment) - MAX_HISTORICAL_RECORD;
	historic_moment *hm;
	LOOP_OVER(hm, historic_moment)
		if (hm->allocation_id >= recorded_time)
			Historian::write_command(TO, hm);
	for (int f = 0; f < no_preset_cases; f++)
		WRITE_TO(TO, "%d = %S\n", f+1, preset_cases[f]);
	STREAM_CLOSE(TO);
}

void Historian::write_command(OUTPUT_STREAM, historic_moment *hm) {
	WRITE("?%d.", hm->epoch);
	text_stream *tok;
	LOOP_OVER_LINKED_LIST(tok, text_stream, hm->token_list) WRITE(" %S", tok);
	WRITE("\n");
}
