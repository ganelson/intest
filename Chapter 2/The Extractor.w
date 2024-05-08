[Extractor::] The Extractor.

To extract the text of a test case from its file on disc.

@ Recall that each test case lives somewhere in a file.

Our main task in this section if to extract that test case, which is a
trivial operation for |PLAIN_FORMAT| -- the entire file is the test case --
but non-trivial for the other cases, and requires some exhausting parsing.

=
typedef struct extraction_state {
	text_stream *DEST;
	struct test_case *tc;
	struct linked_list *case_list; /* of |test_case| */
	int documentation_found;
	int file_format;
	int seek_ref;
	int examples_found;
	int about_to_extract;
	int now_extracting;
	int continue_script;
	int extraction_line_count;
	int extractor_command;
	int concordance_offset;
	int skip_next;
	int no_kv_pairs;
	struct text_stream *keys[MAX_METADATA_PAIRS];
	struct text_stream *values[MAX_METADATA_PAIRS];
	struct text_stream *to_use_recipe;
	struct text_stream *stars;
	struct text_stream *title;
	text_stream *force_vm;
} extraction_state;

@ The Extractor can be called with four commands, all (not coincidentally)
action commands: |SOURCE_ACTION|, |SCRIPT_ACTION|, |CONCORDANCE_ACTION| and
|CENSUS_ACTION|. The first three indeed implement |-source|, |-script| and
|-concordance|, but the Extractor is used for other purposes too. In
|CENSUS_ACTION|, it is used simply to identify the test cases in a file.
The Extractor can also be called from Delia code. So it's a more
general-purpose function than it looks.

=
void Extractor::run(linked_list *L, OUTPUT_STREAM, test_case *tc, filename *F, int format, int ref,
	int cmd, text_stream *recipe_name) {
	extraction_state es;
	es.tc = tc;
	es.case_list = L;
	es.DEST = OUT;
	es.file_format = format;
	es.seek_ref = ref;
	es.documentation_found = FALSE;
	es.examples_found = 0;
	es.about_to_extract = FALSE;
	es.now_extracting = FALSE;
	es.continue_script = FALSE;
	es.extraction_line_count = 0;
	es.extractor_command = cmd;
	es.concordance_offset = 0;
	es.force_vm = NULL;
	es.to_use_recipe = recipe_name;
	es.skip_next = FALSE;
	es.no_kv_pairs = 0;
	es.stars = NULL;
	es.title = NULL;
	TextFiles::read(F, FALSE, "can't open test case file", TRUE, &Extractor::fan, NULL, &es);
}

void Extractor::fan(text_stream *line, text_file_position *tfp, void *ves) {
	extraction_state *es = ves;

	@<Consider entering extraction mode@>;
	if (es->now_extracting) {
		@<Extract the line@>;
		@<Consider leaving extraction mode@>;
	}
}

@<Consider entering extraction mode@> =
	switch (es->file_format) {
		case PLAIN_FORMAT: @<Consider entering extraction mode for PLAIN@>;
			break;
		case ANNOTATED_FORMAT: @<Consider entering extraction mode for ANNOTATED@>;
			break;
		case ANNOTATED_PROBLEM_FORMAT: @<Consider entering extraction mode for ANNOTATED PROBLEM@>;
			break;
		case EXAMPLE_FORMAT: @<Consider entering extraction mode for EXAMPLE@>;
			break;
		case EXTENSION_FORMAT: @<Consider entering extraction mode for EXTENSION@>;
			break;
	}

@ If the file is plain text, always go into extraction mode from line 1
onwards, so that we capture the entire file. If the opening line is a
double-quoted text, then that's the title for the test case.

@<Consider entering extraction mode for PLAIN@> =
	if (tfp->line_count == 1) {
		match_results mr = Regexp::create_mr();
		if ((Regexp::match(&mr, line, U"\"(%c*?)\" *")) && (es->tc)) {
			RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
			Regexp::dispose_of(&mr);
		}
		es->now_extracting = TRUE;
	}

@ An annotated case opens with key-value metadata pairs, then is verbatim
after the first line not matching this.

@<Consider entering extraction mode for ANNOTATED@> =
	if (es->now_extracting == FALSE) {
		if (tfp->line_count == 1) {
			if ((es->extractor_command == CENSUS_ACTION) && (es->tc == NULL))
				es->tc = RecipeFiles::observe_in_annotated_case(
					es->case_list, es->force_vm, es->to_use_recipe);
		}
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"(%C+) *: *(%c*) *")) {
			text_stream *key = mr.exp[0], *value = mr.exp[1];
			if (tfp->line_count == 1) {
				if (Str::eq(key, I"Test") == FALSE) {
					es->now_extracting = TRUE;
				} else {
					RecipeFiles::NameTestCase(es->tc, value);
				}
			}
			if ((es->now_extracting == FALSE) && (es->tc))
				RecipeFiles::AddKVPair(es->tc, key, value);
		} else if (Str::is_whitespace(line)) {
			es->now_extracting = TRUE;
			return; /* do not include the blank line ending the pairs */
		}
		Regexp::dispose_of(&mr);
	}

@ An annotated case opens with key-value metadata pairs, then is verbatim
after the first line not matching this.

@<Consider entering extraction mode for ANNOTATED PROBLEM@> =
	if (es->now_extracting == FALSE) {
		if (tfp->line_count == 1) {
			if ((es->extractor_command == CENSUS_ACTION) && (es->tc == NULL))
				es->tc = RecipeFiles::observe_in_annotated_problem(
					es->case_list, es->force_vm, es->to_use_recipe);
		}
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"(%C+) *: *(%c*) *")) {
			text_stream *key = mr.exp[0], *value = mr.exp[1];
			if (tfp->line_count == 1) {
				if (Str::eq(key, I"Problem")) {
					RecipeFiles::NameTestCase(es->tc, value);
					RecipeFiles::AddKVPair(es->tc, I"Warning", I"No");
				} else if (Str::eq(key, I"Warning")) {
					RecipeFiles::NameTestCase(es->tc, value);
					RecipeFiles::AddKVPair(es->tc, I"Warning", I"Yes");
				} else {
					es->now_extracting = TRUE;
				}
			}
			if ((es->now_extracting == FALSE) && (es->tc) && (Str::ne(key, I"Warning")))
				RecipeFiles::AddKVPair(es->tc, key, value);
		} else if (Str::is_whitespace(line)) {
			es->now_extracting = TRUE;
			return; /* do not include the blank line ending the pairs */
		}
		Regexp::dispose_of(&mr);
	}

@ See the Inform 7 documentation examples to explain this more fully, but
this is a typical start of an EXAMPLE file:
= (text)
	* Printing the banner text
	Several lines of metadata
	
	The descriptive text usually follows, but at some point -
	
	    {*}"Bikini Atoll" by Edward Teller
	
	    The Hut and the Tropical Beach are rooms.
=
The test case can only begin after the header, lines of which can never open
with the paste markers |{*}| or |{**}|, so the following safely ignores
the header:

@<Consider entering extraction mode for EXAMPLE@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%C+) *: *(%c*) *")) {
		text_stream *key = mr.exp[0], *value = mr.exp[1];
		if (Str::eq(key, I"Example")) {
			es->no_kv_pairs = 0;
			es->skip_next = FALSE;
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, line, U"(%C+) *: *(%*+) *(%c*) *")) {
				es->stars = Str::duplicate(mr2.exp[1]);
				es->title = Str::duplicate(mr2.exp[2]);
			}
			Regexp::dispose_of(&mr2);
		} else if ((Str::eq(key, I"For")) && (Str::eq(value, I"Untestable"))) {
			es->skip_next = TRUE;
		} else if (es->no_kv_pairs < MAX_METADATA_PAIRS-1) {
			es->keys[es->no_kv_pairs] = Str::duplicate(key);	
			es->values[es->no_kv_pairs] = Str::duplicate(value);
			es->no_kv_pairs++;
		}
	}
	Regexp::dispose_of(&mr);
	TEMPORARY_TEXT(line_content)
	if ((Str::begins_with_wide_string(line, U"\t{*}")) && (es->skip_next == FALSE)) {
		Str::copy_tail(line_content, line, 4);
		if (es->examples_found++ == 0) {
			Str::clear(line);
			WRITE_TO(line, "\t%S", line_content);
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, line, U"%t\"(%c*?)\" *") ||
				Regexp::match(&mr, line, U"%t\"(%c*?)\" *by *%c*") ) {
				if (es->extractor_command == CENSUS_ACTION)
					es->tc = RecipeFiles::observe_in_example(
						es->case_list, es->force_vm, es->to_use_recipe);
				if (es->tc) {
					if (Str::len(es->title) > 0)
						RecipeFiles::NameTestCase(es->tc, es->title);
					else
						RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
					if (Str::len(es->stars) > 0)
						RecipeFiles::AddKVPair(es->tc, I"Stars", es->stars);
					for (int i=0; i<es->no_kv_pairs; i++)
						RecipeFiles::AddKVPair(es->tc, es->keys[i], es->values[i]);
				}
			}
			Regexp::dispose_of(&mr);
			es->now_extracting = TRUE;
		} else {
			es->now_extracting = FALSE;
		}
	}
	if ((es->extraction_line_count > 0) &&
		(Str::begins_with_wide_string(line, U"\t{**}"))) {
		Str::copy_tail(line_content, line, 5);
		if (es->examples_found == 1) {
			Str::clear(line);
			WRITE_TO(line, "\t%S", line_content);
			es->now_extracting = TRUE;
		}
	}
	DISCARD_TEXT(line_content)

@ Examples are found after the |---- Documentation ----| divider in an
extension file. There can be more than one.

@<Consider entering extraction mode for EXTENSION@> =
	match_results mr = Regexp::create_mr();
	if ((tfp->line_count == 1) && (Regexp::match(&mr, line, U"%c*for Glulx only%c*")))
		es->force_vm = Str::new_from_ISO_string("G");
	if (Regexp::match(&mr, line, U" *---- +DOCUMENTATION +---- *"))
		es->documentation_found = TRUE;
	else if (Regexp::match(&mr, line, U" *---- +Documentation +---- *"))
		es->documentation_found = TRUE;
	else if (Regexp::match(&mr, line, U" *---- +documentation +---- *"))
		es->documentation_found = TRUE;
	if (es->documentation_found) {
		if (Regexp::match(&mr, line, U" *Example: *%c*")) {
			es->now_extracting = FALSE;
			es->examples_found++;
			es->about_to_extract = TRUE;
			if (es->extractor_command == CENSUS_ACTION)
				es->tc = RecipeFiles::observe_in_extension(es->case_list,
					es->examples_found, es->force_vm, es->to_use_recipe);
		}
		if ((es->about_to_extract) && (Str::begins_with_wide_string(line, U"\t*:"))) {
			es->about_to_extract = FALSE;
			int i = 3;
			while (Regexp::white_space(Str::get_at(line, i))) i++;
			TEMPORARY_TEXT(ext_eg)
			Str::copy_tail(ext_eg, line, i);
			if ((es->extractor_command == CENSUS_ACTION) ||
				(es->examples_found == es->seek_ref)) {
				if (Regexp::match(&mr, ext_eg, U"\"(%c*?)\" *") ||
					Regexp::match(&mr, ext_eg, U"\"(%c*?)\" *by *%c*")) {
					if (es->tc) {
						RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
					}
				}
				es->now_extracting = TRUE;
				Extractor::line_out(ext_eg, tfp, es);
				return;
			}
			DISCARD_TEXT(ext_eg)
		}
	}
	Regexp::dispose_of(&mr);

@ For a PLAIN file, we never leave extraction mode: we extract the whole thing.
For an EXAMPLE or EXTENSION, we stop as soon as we find a non-white-space
character in column 1.

@<Consider leaving extraction mode@> =
	if ((es->file_format != PLAIN_FORMAT) &&
		(es->file_format != ANNOTATED_FORMAT) &&
		(es->file_format != ANNOTATED_PROBLEM_FORMAT) &&
		(Str::len(line) > 0) &&
		(Regexp::white_space(Str::get_first_char(line)) == FALSE))
			es->now_extracting = FALSE;

@ In EXAMPLE and EXTENSION files, the material is all one tab stop in, so
we get rid of that before passing the line through.

@<Extract the line@> =
	if ((es->file_format == PLAIN_FORMAT) ||
		(es->file_format == ANNOTATED_FORMAT) ||
		(es->file_format == ANNOTATED_PROBLEM_FORMAT))
		Extractor::line_out(line, tfp, es);
	else if (Str::get_first_char(line) == '\t') {
		TEMPORARY_TEXT(rl)
		Str::copy(rl, line);
		Str::delete_first_character(rl);
		Extractor::line_out(rl, tfp, es);
		DISCARD_TEXT(rl)
	} else if (Regexp::string_is_white_space(line)) Extractor::line_out(NULL, tfp, es);

@ The effect of the above, then, is that the test case(s) are fed, one line
at a time, into the following function. What happens to these lines depends
on what the Extractor has been asked to do.

=
void Extractor::line_out(text_stream *text, text_file_position *tfp, extraction_state *es) {
	es->extraction_line_count++;
	match_results mr = Regexp::create_mr();
	switch (es->extractor_command) {
		case SOURCE_ACTION: @<Perform a SOURCE on the line@>; break;
		case SCRIPT_ACTION: @<Perform a SCRIPT on the line@>; break;
		case CONCORDANCE_ACTION: @<Perform a CONCORDANCE on the line@>; break;
		case CENSUS_ACTION: break; /* the content of the cases doesn't matter */
	}
	Regexp::dispose_of(&mr);
}

@ When we SOURCE, we write the line to the text stream |es->DEST|, but
we also note in passing whether it contains an Inform 7 "Test me with..."
or "Use command line echoing" sentence.

@<Perform a SOURCE on the line@> =
	if ((text) && (es->tc)) {
		if (Regexp::match(&mr, text, U"%c*Test me with \"%c*"))
			es->tc->test_me_detected = TRUE;
		if (Regexp::match(&mr, text, U"%c*Use command line echoing%c*"))
			es->tc->command_line_echoing_detected = TRUE;
		WRITE_TO(es->DEST, "%S\n", text);
	} else if (text) WRITE_TO(es->DEST, "%S\n", text);
	else WRITE_TO(es->DEST, "\n");

@ On a SCRIPT extraction, we look for the commands in a "Test me with..."
sentence. Again, useful only for Inform 7.

@<Perform a SCRIPT on the line@> =
	if (text) {
		if (Regexp::match(&mr, text, U"Test me with \"(%c*?)\"%c*")) {
			Extractor::script_out(es->DEST, mr.exp[0]);
		} else if (Regexp::match(&mr, text, U"Test me with \"(%c*?)")) {
			Extractor::script_out(es->DEST, mr.exp[0]);
			es->continue_script = TRUE;
		} else if (es->continue_script) {
			if (Regexp::match(&mr, text, U"(%c*?)\"%c*?")) {
				Extractor::script_out(es->DEST, mr.exp[0]);
				es->continue_script = FALSE;
			} else Extractor::script_out(es->DEST, text);
		}
	}

@ This unpacks a script like |yes / no / maybe| into a column with one
command per line:
= (text)
	yes
	no
	maybe
=
which it pours into the given text stream. All white space around the slashes
is soaked up.

=
void Extractor::script_out(OUTPUT_STREAM, text_stream *from) {
	TEMPORARY_TEXT(script)
	Str::copy(script, from);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, script, U"(%c+?) */ *(%c*)")) {
		if (Str::len(mr.exp[0]) > 0) WRITE("%S\n", mr.exp[0]);
		Str::copy(script, mr.exp[1]);
	}
	if (Str::len(script) > 0) WRITE("%S\n", script);
	Regexp::dispose_of(&mr);
	DISCARD_TEXT(script)
}

@ A CONCORDANCE implements the |-concordance| command-line feature of Inform.
It essentially shows how to reconcile line numbers in the original file with
line numbers in the test case.

@<Perform a CONCORDANCE on the line@> =
	int offset = tfp->line_count - es->extraction_line_count;
	if (es->concordance_offset != offset) {
		es->concordance_offset = offset;
		WRITE_TO(es->DEST, "%d +%d\n", es->extraction_line_count, offset);
	}

@ Slightly cheekily, the Extractor with almost all features turned off can
be used as a way to copy a file into a text stream verbatim, like the Unix
|cat| utility:

=
void Extractor::cat(OUTPUT_STREAM, filename *F) {
	Extractor::run(NULL, OUT, NULL, F, PLAIN_FORMAT, 0, SOURCE_ACTION, NULL);
}
