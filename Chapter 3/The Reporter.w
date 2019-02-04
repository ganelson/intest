[Reporter::] The Reporter.

To produce reports for use in the Inform user interface app.

@h About reports.
This whole section applies only for the non-standard use case where Intest
is running inside the Inform user interface app. A "report" is then an
HTML page summarising the results of testing, which that app can then display.
Reports are heavily tied to the standard recipe for testing Inform source,
when it's run through I7, then I6, then executed to obtain a transcript of
the resulting play. As a result, any individual test can fail in a set
number of ways:

@d I7_FAILED_OUTCOME 1 /* I7 issued problem messages */
@d I6_FAILED_OUTCOME 2 /* I6 issued error messages */
@d CURSED_OUTCOME 3 /* where there's no ideal transcript to compare against */
@d WRONG_TRANSCRIPT_OUTCOME 4 /* the actual transcript didn't match the ideal */
@d PERFECT_OUTCOME 5

@h Report feature.
The following implements the |-report| command line feature.

=
void Reporter::report_single(OUTPUT_STREAM, test_case *tc, action_item *ai) {
	report_state rs;
	@<Initialise the report state@>;
	TextFiles::read(rs.prototype_HTML_file, FALSE, "can't open test report file", TRUE,
		&Reporter::filter, NULL, &rs);
}

@ =
typedef struct report_state {
	text_stream *REPORT_TO;
	struct test_case *test;
	int success_code; /* one of the |*_OUTCOME| constants above */
	int turns_keyed; /* number of commands auto-entered from a TEST ME */
	struct filename *prototype_HTML_file; /* ultimately from the app */
	struct text_stream *relevant_node_ID; /* to provide in-app links to the Skein */
	int stage; /* where we are in scanning the prototype */
	int first_flag;
	int last_flag;
	char test_case_letter; /* 'A' to 'Z': for cases in an extension project */
} report_state;

@<Initialise the report state@> =
	rs.test = tc;
	rs.success_code = ai->assoc_number;
	rs.turns_keyed = ai->assoc_number2;
	rs.prototype_HTML_file = ai->assoc_file1;
	rs.relevant_node_ID = ai->assoc_text;
	rs.stage = 1;
	rs.first_flag = FALSE;
	rs.last_flag = FALSE;
	rs.REPORT_TO = OUT;
	if (tc->letter_reference >= 1)
		rs.test_case_letter = (char) (((int) 'A') + tc->letter_reference - 1);
	else
		rs.test_case_letter = 0;

@ So, then, the following filter is run line by line on a prototype HTML file
nominated by the UI app. We will splice in our report.

=
void Reporter::filter(text_stream *line_text, text_file_position *tfp, void *vrs) {
	report_state *rs = vrs;
	text_stream *OUT = rs->REPORT_TO;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, L" <!--CONTENT BEGINS-->")) {
		WRITE("<!--INTEST REPORT BEGINS-->\n");
		rs->stage = 2;
	}
	else if (Regexp::match(&mr, line_text, L" <!--BANNER BEGINS-->")) rs->stage = 3;
	else if (Regexp::match(&mr, line_text, L" <!--HEADING BEGINS-->")) {
		rs->stage = 4;
		@<Insert test report header@>;
	} else if (Regexp::match(&mr, line_text, L" <!--HEADING ENDS-->")) rs->stage = 5;
	else if (Regexp::match(&mr, line_text, L" <!--BANNER ENDS-->")) rs->stage = 6;
	else if (Regexp::match(&mr, line_text, L" <!--PROBLEMS BEGIN-->")) {
		rs->stage = 7;
		@<Insert additional material@>;
	}
	else if (Regexp::match(&mr, line_text, L" <!--PROBLEMS END-->")) rs->stage = 8;
	else if (Regexp::match(&mr, line_text, L" <!--CONTENT ENDS-->")) {
		rs->stage = 9;
		@<Insert test report footer@>;
		WRITE("<!--INTEST REPORT ENDS-->\n");
	} else {
		if ((rs->stage == 1) || (rs->stage == 2) || (rs->stage == 3) ||
			(rs->stage == 5) || (rs->stage == 9) ||
				((rs->stage == 7) && (rs->success_code == I7_FAILED_OUTCOME)) ||
				((rs->stage == 7) && (rs->success_code == I6_FAILED_OUTCOME))
			)
			@<Filter existing report, adjusting links@>;
	}
	Regexp::dispose_of(&mr);
}

@<Insert test report header@> =
	if ((rs->success_code == PERFECT_OUTCOME) || (rs->success_code == CURSED_OUTCOME))
		WRITE("<div class=\"headingboxSucceeded\">\n");
	else
		WRITE("<div class=\"headingboxFailed\">\n");
	WRITE("<div class=\"headingtext\">");
	WRITE("Example ");
	if (rs->test_case_letter) WRITE("%c: ", rs->test_case_letter);
	WRITE("&#8216;%S&#8217;: ", rs->test->test_case_title);
	switch (rs->success_code) {
		case WRONG_TRANSCRIPT_OUTCOME: WRITE("Failed"); break;
		case PERFECT_OUTCOME: WRITE("Succeeded"); break;
		case CURSED_OUTCOME: WRITE("Partly Succeeded"); break;
		default: WRITE("Couldn't Test"); break;
	}
	WRITE("</div>\n");
	WRITE("<div class=\"headingrubric\">");
	switch (rs->success_code) {
		case I7_FAILED_OUTCOME: WRITE("Problem messages meant it wouldn't translate"); break;
		case I6_FAILED_OUTCOME: WRITE("Translated but failed to compile in Inform 6"); break;
		case CURSED_OUTCOME: WRITE("Translated but has no blessed transcript to check against"); break;
		case WRONG_TRANSCRIPT_OUTCOME: WRITE("Translated but produced the wrong transcript"); break;
		case PERFECT_OUTCOME: WRITE("Translated and produced the correct transcript"); break;
	}
	WRITE("</div>\n");
	WRITE("</div>\n");

@<Insert additional material@> =
	WRITE("<p class=\"tightin1\">&nbsp;"
		"<a href=\"source:story.ni");
	if (rs->test_case_letter) WRITE("?case=%c", rs->test_case_letter);
	WRITE("#line1\"><img border=0 src=inform:/doc_images/Reveal.png></a> "
		"Source text");
	if ((rs->success_code != I6_FAILED_OUTCOME) && (rs->success_code != I7_FAILED_OUTCOME)) {
		WRITE("&nbsp;&bull;");
		@<Insert link to transcript@>;
		WRITE("Transcript of play (%d turn%s)",
			rs->turns_keyed, (rs->turns_keyed == 1)?"":"s");
	} else {
		WRITE("<br>&nbsp;\n");
	}
	WRITE("</p>\n");
	switch (rs->success_code) {
		case CURSED_OUTCOME:
			WRITE("<p class=\"in2\">This translated fine, so "
				"I could play it. ");
			if (rs->turns_keyed > 0)
				WRITE("I automatically typed in %d command%s extracted from the "
					"TEST ME in the source. ",
					rs->turns_keyed, (rs->turns_keyed == 1)?"":"s");
			else
				WRITE("The source text didn't have a TEST ME included, so I didn't "
					"type any commands into it. ");
			WRITE("(Click");
			@<Insert link to transcript@>;
			WRITE("to see.)</p>");
			WRITE("<p class=\"in2\">But I didn't know what to "
				"check the transcript against, so I can't say whether it's "
				"correct. Take a look: if it's right, 'bless' the transcript "
				"with the tick icons. I will then use that on future tests.</p>\n");
			break;
		case WRONG_TRANSCRIPT_OUTCOME:
			WRITE("<p class=\"in2\">This translated fine, so "
				"I could play it. ");
			if (rs->turns_keyed > 0)
				WRITE("(I automatically typed in %d command%s extracted from the "
					"TEST ME in the source.) ",
					rs->turns_keyed, (rs->turns_keyed == 1)?"":"s");
			else
				WRITE("(The source text didn't have a TEST ME included, so I didn't "
					"type any commands into it.) ");
			WRITE("But the resulting text didn't match the "
				"'blessed' version. (Click");
			@<Insert link to transcript@>;
			WRITE("to see what went wrong.)</p>");
			WRITE("<p class=\"in2\">If you intended this, you "
				"can 'bless' the new version as better, and I'll compare against "
				"that in future tests. But if it's just plain wrong, I can't help: "
				"you have some work to do on the source.</p>");
			break;
	}

@<Insert link to transcript@> =
	WRITE("&nbsp;<a href='skein:%S", rs->relevant_node_ID);
	if (rs->test_case_letter) WRITE("?case=%c", rs->test_case_letter);
	WRITE("'><img border=0 src=inform:/doc_images/Transcript.png></a>&nbsp;");

@<Insert test report footer@> =
	WRITE("<p></p>\n");

@<Filter existing report, adjusting links@> =
	WRITE("%S\n", line_text);

@h Combine feature.
The following implements the |-combine| command line feature. Essentially it
takes a batch of reports made by |-report| and merges them together.

=
void Reporter::combine(OUTPUT_STREAM, int count, filename *base_filename) {
	for (int i = 1; i <= count; i++) {
		report_state rs;
		@<Initialise the report state for combination@>;
		TextFiles::read(rs.prototype_HTML_file, FALSE, "can't open test report file", TRUE,
			&Reporter::combine_filter, NULL, &rs);
	}
}

@<Initialise the report state for combination@> =
	rs.test = NULL;
	rs.success_code = -1;
	pathname *P = Filenames::get_path_to(base_filename);
	TEMPORARY_TEXT(NEWLEAF);
	Filenames::write_unextended_leafname(NEWLEAF, base_filename);
	Str::truncate(NEWLEAF, 16);
	WRITE_TO(NEWLEAF, "-%d.html", i);
	rs.prototype_HTML_file = Filenames::in_folder(P, NEWLEAF);
	DISCARD_TEXT(NEWLEAF);
	rs.relevant_node_ID = NULL;
	rs.first_flag = FALSE;
	rs.last_flag = FALSE;
	if (i == 1) rs.first_flag = TRUE;
	else if (i == count) rs.last_flag = TRUE;
	rs.stage = 1;
	rs.REPORT_TO = OUT;
	rs.test_case_letter = (char) (((int) 'A') + i - 1);

@ =
void Reporter::combine_filter(text_stream *line_text, text_file_position *tfp, void *vrs) {
	report_state *rs = vrs;
	text_stream *OUT = rs->REPORT_TO;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, L"<!--INTEST REPORT BEGINS-->")) rs->stage = 2;
	else if (Regexp::match(&mr, line_text, L"<!--INTEST REPORT ENDS-->")) rs->stage = 3;
	else if (((rs->stage == 1) && (rs->first_flag)) || ((rs->stage == 3) && (rs->last_flag)))
		WRITE("%S\n", line_text);
	else if (rs->stage == 2) {
		WRITE("%S\n", line_text);
	}
	Regexp::dispose_of(&mr);
}
