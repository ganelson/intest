[Extractor::] The Extractor.

To extract the text of a test case from its file on disc.

@ Recall that each test case lives somewhere in a file, whose format is one
of |PLAIN_FORMAT|, |EXAMPLE_FORMAT| or |EXTENSION_FORMAT|, though the latter two
only ever arise when testing Inform 7.

Our main task in this section if to extract that test case, which is a
trivial operation for |PLAIN_FORMAT| -- the entire file is the test case --
but non-trivial for the other two, and requires some exhausting parsing.

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
	struct text_stream *to_use_recipe;
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
		if ((Regexp::match(&mr, line, L"\"(%c*?)\" *")) && (es->tc)) {
			RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
			Regexp::dispose_of(&mr);
		}
		es->now_extracting = TRUE;
	}

@ See the Inform 7 documentation examples to explain this more fully, but
this is a typical start of an EXAMPLE file:

	|* Printing the banner text|
	|(Banner printing at appropriate times; Bikini Atoll)|
	|Delaying the banner for later.|
	||
	|    {*}"Bikini Atoll" by Edward Teller|
	||
	|    The Hut and the Tropical Beach are rooms.|

The test case can only begin after the header, which always occupies three
lines, and we look out for the |{*}| marker.

@<Consider entering extraction mode for EXAMPLE@> =
	TEMPORARY_TEXT(line_content);
	if ((tfp->line_count > 3) && (Str::begins_with_wide_string(line, L"\t{*}"))) {
		Str::copy_tail(line_content, line, 4);
		if (es->examples_found++ == 0) {
			Str::clear(line);
			WRITE_TO(line, "\t%S", line_content);
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, line, L"%t\"(%c*?)\" *")) {
				if (es->extractor_command == CENSUS_ACTION)
					es->tc = RecipeFiles::observe_in_example(
						es->case_list, es->force_vm, es->to_use_recipe);
				if (es->tc) RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
			}
			Regexp::dispose_of(&mr);
			es->now_extracting = TRUE;
		} else {
			es->now_extracting = FALSE;
		}
	}
	if ((es->extraction_line_count > 0) &&
		(Str::begins_with_wide_string(line, L"\t{**}"))) {
		Str::copy_tail(line_content, line, 5);
		if (es->examples_found == 1) {
			Str::clear(line);
			WRITE_TO(line, "\t%S", line_content);
			es->now_extracting = TRUE;
		}
	}
	DISCARD_TEXT(line_content);

@ Examples are found after the |---- Documentation ----| divider in an
extension file. There can be more than one.

@<Consider entering extraction mode for EXTENSION@> =
	match_results mr = Regexp::create_mr();
	if ((tfp->line_count == 1) && (Regexp::match(&mr, line, L"%c*for Glulx only%c*")))
		es->force_vm = Str::new_from_ISO_string("G");
	if (Regexp::match(&mr, line, L" *---- +DOCUMENTATION +---- *"))
		es->documentation_found = TRUE;
	else if (Regexp::match(&mr, line, L" *---- +Documentation +---- *"))
		es->documentation_found = TRUE;
	else if (Regexp::match(&mr, line, L" *---- +documentation +---- *"))
		es->documentation_found = TRUE;
	if (es->documentation_found) {
		if (Regexp::match(&mr, line, L" *Example: %*+ %c*")) {
			es->now_extracting = FALSE;
			es->examples_found++;
			es->about_to_extract = TRUE;
			if (es->extractor_command == CENSUS_ACTION)
				es->tc = RecipeFiles::observe_in_extension(es->case_list,
					es->examples_found, es->force_vm, es->to_use_recipe);
		}
		if ((es->about_to_extract) && (Str::begins_with_wide_string(line, L"\t*:"))) {
			es->about_to_extract = FALSE;
			int i = 3;
			while (Regexp::white_space(Str::get_at(line, i))) i++;
			TEMPORARY_TEXT(ext_eg);
			Str::copy_tail(ext_eg, line, i);
			if ((es->extractor_command == CENSUS_ACTION) ||
				(es->examples_found == es->seek_ref)) {
				if ((Regexp::match(&mr, ext_eg, L"\"(%c*?)\" *")) && (es->tc))
					RecipeFiles::NameTestCase(es->tc, mr.exp[0]);
				es->now_extracting = TRUE;
				Extractor::line_out(ext_eg, tfp, es);
				return;
			}
			DISCARD_TEXT(ext_eg);
		}
	}
	Regexp::dispose_of(&mr);

@ For a PLAIN file, we never leave extraction mode: we extract the whole thing.
For an EXAMPLE or EXTENSION, we stop as soon as we find a non-white-space
character in column 1.

@<Consider leaving extraction mode@> =
	if ((es->file_format != PLAIN_FORMAT) &&
		(Str::len(line) > 0) &&
		(Regexp::white_space(Str::get_first_char(line)) == FALSE))
			es->now_extracting = FALSE;

@ In EXAMPLE and EXTENSION files, the material is all one tab stop in, so
we get rid of that before passing the line through.

@<Extract the line@> =
	if (es->file_format == PLAIN_FORMAT) Extractor::line_out(line, tfp, es);
	else if (Str::get_first_char(line) == '\t') {
		TEMPORARY_TEXT(rl);
		Str::copy(rl, line);
		Str::delete_first_character(rl);
		Extractor::line_out(rl, tfp, es);
		DISCARD_TEXT(rl);
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
		if (Regexp::match(&mr, text, L"%c*Test me with \"%c*"))
			es->tc->test_me_detected = TRUE;
		if (Regexp::match(&mr, text, L"%c*Use command line echoing%c*"))
			es->tc->command_line_echoing_detected = TRUE;
		WRITE_TO(es->DEST, "%S\n", text);
	} else if (text) WRITE_TO(es->DEST, "%S\n", text);
	else WRITE_TO(es->DEST, "\n");

@ On a SCRIPT extraction, we look for the commands in a "Test me with..."
sentence. Again, useful only for Inform 7.

@<Perform a SCRIPT on the line@> =
	if (text) {
		if (Regexp::match(&mr, text, L"Test me with \"(%c*?)\".*")) {
			Extractor::script_out(es->DEST, mr.exp[0]);
		} else if (Regexp::match(&mr, text, L"Test me with \"(%c*?)")) {
			Extractor::script_out(es->DEST, mr.exp[0]);
			es->continue_script = TRUE;
		} else if (es->continue_script) {
			if (Regexp::match(&mr, text, L"(%c*?)\"%c*?")) {
				Extractor::script_out(es->DEST, mr.exp[0]);
				es->continue_script = FALSE;
			} else Extractor::script_out(es->DEST, text);
		}
	}

@ This unpacks a script like |yes / no / maybe| into a column with one
command per line:

	|yes|
	|no|
	|maybe|

which it pours into the given text stream. All white space around the slashes
is soaked up.

=
void Extractor::script_out(OUTPUT_STREAM, text_stream *from) {
	TEMPORARY_TEXT(script);
	Str::copy(script, from);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, script, L"(%c+?) */ *(%c*)")) {
		if (Str::len(mr.exp[0]) > 0) WRITE("%S\n", mr.exp[0]);
		Str::copy(script, mr.exp[1]);
	}
	if (Str::len(script) > 0) WRITE("%S\n", script);
	Regexp::dispose_of(&mr);
	DISCARD_TEXT(script);
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
