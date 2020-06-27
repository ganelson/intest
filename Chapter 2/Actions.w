[Actions::] Actions.

To parse and carry out requests to do something.

@h Reading the command line.
Suppose the tester invoked Intest as
= (text as ConsoleText)
	$ intest/Tangled/intest inweb -bless plain twinprimes
=
The following routine will be called to take care of the actual command:
= (text)
	-bless plain twinprimes
=
The tokens |-bless|, |plain| and |twinprimes| will be in the array |argv|,
at indexes |from_arg_n| onwards. |to_arg_n| is the index after the last one.
The token list can contain multiple actions, one after the other.

=
void Actions::read_do_instructions(intest_instructions *args,
	int from_arg_n, int to_arg_n, text_stream **argv) {
	@<Log the do instructions@>;

	for (int index=from_arg_n; index<to_arg_n; index++) {
		text_stream *opt = argv[index];

		int action = TEST_ACTION; /* which command is used */
		int ops_from = index+1, ops_to = index; /* operands run from |ops_from| to |ops_to| */
		filename *redirect_output = NULL; /* optional file to redirect output to */

		@<Scan the command and advance index to the end of it@>;
		@<Translate the command into action item structures@>;
	}
}

@<Log the do instructions@> =
	if (Log::aspect_switched_on(INSTRUCTIONS_DA)) {
		LOG("doing:");
		for (int i=from_arg_n; i<to_arg_n; i++) LOG(" %S", argv[i]);
		LOG("\n");
	}
	
@ The |arity| is the expected number of operands which will follow the
command, or is |-1| to mean "any positive number of operands".

@<Scan the command and advance index to the end of it@> =		
	int pos = index + 1, arity = -1;
	@<Parse the command name@>;
	@<Scan for the operands@>;
	@<Parse an optional redirection filename@>;
	index = pos - 1;

@ A command begins with one of the following tokens: or, if it doesn't, we
pretend that it begins with |test|.

The following enumerates the "do commands", or as we'll call them in this
section, "actions":

@e BBDIFF_ACTION from 1
@e BLESS_ACTION
@e CATALOGUE_ACTION
@e CENSUS_ACTION
@e COMBINE_REPORTS_ACTION
@e CONCORDANCE_ACTION
@e CURSE_ACTION
@e DEBUGGER_ACTION
@e DIFF_ACTION
@e SOURCE_ACTION
@e FIND_ACTION
@e OPEN_ACTION
@e REBLESS_ACTION
@e REPORT_ACTION
@e SCRIPT_ACTION
@e SHOW_ACTION
@e SHOW_I6_ACTION
@e SHOW_TRANSCRIPT_ACTION
@e SKEIN_ACTION
@e TEST_ACTION

@d SCHEDULED_TEST_ACTION 100 /* must be more than all of the above */

@<Parse the command name@> =
	if (Str::eq(opt, I"-catalogue")) { action = CATALOGUE_ACTION; arity = 0; }
	else if (Str::eq(opt, I"-find")) { action = FIND_ACTION; arity = 1; }
	else if (Str::eq(opt, I"-test-skein")) { action = SKEIN_ACTION; arity = 1; }
	else if (Str::eq(opt, I"-script")) { action = SCRIPT_ACTION; }
	else if (Str::eq(opt, I"-source")) { action = SOURCE_ACTION; }
	else if (Str::eq(opt, I"-concordance")) { action = CONCORDANCE_ACTION; }
	else if (Str::eq(opt, I"-report")) { action = REPORT_ACTION; arity = 5; }
	else if (Str::eq(opt, I"-combine")) { action = COMBINE_REPORTS_ACTION; arity = 2; }
	else if (Str::eq(opt, I"-open")) { action = OPEN_ACTION; }
	else if (Str::eq(opt, I"-show")) { action = SHOW_ACTION; }
	else if (Str::eq(opt, I"-show-i6")) { action = SHOW_I6_ACTION; }
	else if (Str::eq(opt, I"-show-t")) { action = SHOW_TRANSCRIPT_ACTION; }
	else if (Str::eq(opt, I"-bbdiff")) { action = BBDIFF_ACTION; }
	else if (Str::eq(opt, I"-diff")) { action = DIFF_ACTION; }
	else if (Str::eq(opt, I"-test")) { action = TEST_ACTION; }
	else if (Str::eq(opt, I"-debug")) { action = DEBUGGER_ACTION; }
	else if (Str::eq(opt, I"-bless")) { action = BLESS_ACTION; }
	else if (Str::eq(opt, I"-curse")) { action = CURSE_ACTION; }
	else if (Str::eq(opt, I"-rebless")) { action = REBLESS_ACTION; }
	else if (Str::get_at(opt, 0) == '-') Errors::fatal_with_text("no such action as: %S", opt);
	else { opt = I"-test"; action = TEST_ACTION; pos = index; }

@ After the command, operands: e.g., in the token list |-bless A B -catalogue|,
the command |-bless| has two operands |A| and |B|. We know that |-catalogue|
is not an operand because it starts with a dash but is not a negative number.
(Thus, |-12| would be allowed as an operand, but |-minustwelve| would not.)

At this point |pos| is the index of the first operand. We must find the range
|ops_from| to |ops_to|.

@<Scan for the operands@> =
	ops_from = pos;
	while (pos < to_arg_n) {
		if ((Str::get_at(argv[pos], 0) == '-') &&
			(!Characters::isdigit(Str::get_at(argv[pos], 1)))) break;
		pos++;
	}
	ops_to = pos-1;
	int count = ops_to - ops_from + 1;
	if (arity >= 0) {
		if (count != arity) {
			if (arity == 0)
				Errors::fatal_with_text("this action takes no case name(s): %S", opt);
			else {
				TEMPORARY_TEXT(M)
				WRITE_TO(M, "the action '%S' takes %d parameters", opt, arity);
				Errors::fatal_with_text("%S", M);
				DISCARD_TEXT(M)
			}
		}
	} else {
		if (count == 0)
			Errors::fatal_with_text("this action must be followed by case name(s): %S", opt);
	}

@ After the operands, there can optionally be |-to F|, where |F| is a filename.

@<Parse an optional redirection filename@> =
	if ((pos+1 < to_arg_n) && (Str::eq(argv[pos], I"-to"))) {
		redirect_output = Filenames::from_text(argv[pos+1]);
		pos += 2;
	}

@<Translate the command into action item structures@> =
	TEMPORARY_TEXT(assoc_text)
	int assoc_number = 0, assoc_number2 = 0;
	filename *assoc_file1 = NULL, *assoc_file2 = NULL;
	switch (action) {
		case REPORT_ACTION: @<Create action item for REPORT@>; break;
		case COMBINE_REPORTS_ACTION: @<Create action item for COMBINE REPORTS@>; break;
		case FIND_ACTION: @<Create action item for FIND@>; break;
		case SKEIN_ACTION: @<Create action item for SKEIN@>; break;
		default: @<Create more typical action items@>; break;
	}
	DISCARD_TEXT(assoc_text)

@<Create action item for REPORT@> =
	if (Str::eq(argv[ops_from+1], I"i7")) assoc_number = I7_FAILED_OUTCOME;
	else if (Str::eq(argv[ops_from+1], I"i6")) assoc_number = I6_FAILED_OUTCOME;
	else if (Str::eq(argv[ops_from+1], I"cursed")) assoc_number = CURSED_OUTCOME;
	else if (Str::eq(argv[ops_from+1], I"wrong")) assoc_number = WRONG_TRANSCRIPT_OUTCOME;
	else if (Str::eq(argv[ops_from+1], I"right")) assoc_number = PERFECT_OUTCOME;
	else Errors::fatal_with_text(
		"expected 'i7', 'i6', 'wrong' or 'right' but found: %S", argv[ops_from+1]);

	assoc_file1 = Filenames::from_text(argv[ops_from+2]);
	assoc_text = argv[ops_from+3];
	if (Str::get_at(assoc_text, 0) == 'n') Str::delete_first_character(assoc_text);
	text_stream *p = argv[ops_from+4];
	if (Str::get_at(p, 0) == 't') assoc_number2 = Str::atoi(p, 1);
	Actions::create(action, redirect_output, argv[ops_from], args,
		assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);

@<Create action item for COMBINE REPORTS@> =
	assoc_file1 = Filenames::from_text(argv[ops_from]);
	text_stream *p = argv[ops_from+1];
	if (Str::get_at(p, 0) == '-') assoc_number = Str::atoi(p, 1);
	if (assoc_number <= 0)
		Errors::fatal_with_text(
			"expected dash then positive integer, e.g., '-5', but found: '%S'", p);
	Actions::create(action, redirect_output, NULL, args,
		assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);

@<Create action item for FIND@> =
	assoc_text = argv[ops_from];
	Actions::create(action, redirect_output, NULL, args,
		assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);

@<Create action item for SKEIN@> =
	assoc_file1 = Filenames::from_text(argv[ops_from]);
	assoc_text = argv[ops_from+1];
	Actions::create(action, redirect_output, NULL, args,
		assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);

@<Create more typical action items@> =
	if (ops_to >= ops_from)
		for (int j = ops_from; j <= ops_to; j++)
			Actions::create(action, redirect_output, argv[j], args,
				assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);
	else
		Actions::create(action, redirect_output, NULL, args,
			assoc_number, assoc_number2, assoc_file1, assoc_file2, assoc_text);

@ So, then, a command such as |-test alpha beta gamma| will cause three
instances of the "action item" structure to be created, of type |TEST_ACTION|
on |alpha|, |beta| and |gamma| respectively.

=
typedef struct action_item {
	int action_type; /* one of the |_ACTION| cases above */
	int test_form;
	struct case_specifier operand;
	struct filename *redirection_filename;
	int assoc_number;
	int assoc_number2;
	struct filename *assoc_file1;
	struct filename *assoc_file2;
	struct text_stream *assoc_text;
	CLASS_DEFINITION
} action_item;

@ As each action item is created, it is added to the "to-do list" for this
run of Intest. (There is just one global to-do list.)

=
void Actions::create(int action, filename *redirect_output, text_stream *op, intest_instructions *args,
	int assoc_number, int assoc_number2, filename *assoc_file1, filename *assoc_file2, text_stream *text) {
	action_item *ai = CREATE(action_item);
	ai->action_type = action;
	ai->redirection_filename = redirect_output;
	ai->assoc_number = assoc_number;
	ai->assoc_number2 = assoc_number2;
	ai->assoc_file1 = assoc_file1;
	ai->assoc_file2 = assoc_file2;
	ai->assoc_text = Str::duplicate(text);
	ai->operand = Actions::parse_specifier(op, args);

	ADD_TO_LINKED_LIST(ai, action_item, args->to_do_list);
}

@ A "case specifier" says what case(s) an action should apply to, and this
can involve a wildcard such as |all|:

=
typedef struct case_specifier {
	struct test_case *specific_case; /* a specific test to apply to... */
	int wild_card; /* ...or a wildcard */
	struct text_stream *regexp_wild_card;
} case_specifier;

@ =
case_specifier Actions::parse_specifier(text_stream *token, intest_instructions *args) {
	case_specifier cs;
	cs.wild_card = Actions::identify_wildcard(token);
	cs.specific_case = NULL;
	cs.regexp_wild_card = NULL;
	if ((token) && (cs.wild_card == TAMECARD)) {
		cs.specific_case = RecipeFiles::find_case(args, token);
		if (cs.specific_case == NULL)
			Errors::fatal_with_text("no such test case as %S", token);
	}
	if ((token) && (cs.wild_card == REGEXP_WILDCARD))
		cs.regexp_wild_card = Str::duplicate(token);
	if ((token) && (cs.wild_card == GROUP_WILDCARD))
		cs.regexp_wild_card = Str::duplicate(token);
	return cs;
}

@h Wildcards.

@d COUNT_WILDCARD_BASE 1001 /* 1001 is |^1|, 1002 is |^2|, ... */
@d EXTENSION_WILDCARD_BASE 101 /* 101 is |A|, 102 is |B|, ... */
@d GROUP_WILDCARD 2
@d REGEXP_WILDCARD 1
@d TAMECARD 0
@d ALL_WILDCARD -1
@d EXAMPLES_WILDCARD -2
@d CASES_WILDCARD -3
@d PROBLEMS_WILDCARD -4
@d EXTENSIONS_WILDCARD -5
@d MAPS_WILDCARD -6

=
int Actions::identify_wildcard(text_stream *token) {
	if (token == NULL) return TAMECARD;
	LOOP_THROUGH_TEXT(pos, token)
		if (Str::get(pos) == '%')
			return REGEXP_WILDCARD;
	int c = Str::get_first_char(token);
	if (c == ':') return GROUP_WILDCARD;
	if (Str::len(token) == 1) {
		if ((c >= 'A') && (c <= 'Z')) return c - 'A' + EXTENSION_WILDCARD_BASE;
		if ((c >= 'a') && (c <= 'z')) return c - 'a' + EXTENSION_WILDCARD_BASE;
	}
	if (Str::eq(token, I"all")) return ALL_WILDCARD;
	if (Str::eq(token, I"examples")) return EXAMPLES_WILDCARD;
	if (Str::eq(token, I"cases")) return CASES_WILDCARD;
	if (Str::eq(token, I"problems")) return PROBLEMS_WILDCARD;
	if (Str::eq(token, I"maps")) return MAPS_WILDCARD;
	if (Str::eq(token, I"extensions")) return EXTENSIONS_WILDCARD;
	if (Str::get_first_char(token) == '^') {
		int n = Str::atoi(token, 1);
		if (n > 0) return n - 1 + COUNT_WILDCARD_BASE;
	}
	return TAMECARD;
}

int Actions::matches_wildcard(test_case *tc, int w) {
	if (w == ALL_WILDCARD) return TRUE;
	if (w == Actions::which_wildcard(tc)) return TRUE;
	return FALSE;
}

int Actions::which_wildcard(test_case *tc) {
	if (tc->format_reference == EXAMPLE_FORMAT) return EXAMPLES_WILDCARD;
	if (tc->test_type == PROBLEM_SPT) return PROBLEMS_WILDCARD;
	if (tc->test_type == MAP_SPT) return MAPS_WILDCARD;
	if (tc->format_reference == EXTENSION_FORMAT) return EXTENSIONS_WILDCARD;
	return CASES_WILDCARD;
}

char *Actions::name_of_wildcard(int w) {
	switch (w) {
		case EXAMPLES_WILDCARD: return "examples"; break;
		case EXTENSIONS_WILDCARD: return "extensions"; break;
		case PROBLEMS_WILDCARD: return "problems"; break;
		case MAPS_WILDCARD: return "maps"; break;
		case CASES_WILDCARD: return "cases"; break;
	}
	return "?";
}

@h Performance.
At this point, parsing is long over. We have to perform the actions in the
to-do list:

=
void Actions::perform(OUTPUT_STREAM, intest_instructions *args) {
	Hasher::read_hashes(args);
	Scheduler::start(args->threads_available);

	int count = 1;
	action_item *ai;
	LOOP_OVER_LINKED_LIST(ai, action_item, args->to_do_list)
		@<Perform this action item@>;

	Scheduler::test(OUT);
	Hasher::write_hashes();
}

@<Perform this action item@> =
	if (ai->operand.wild_card >= COUNT_WILDCARD_BASE) @<Perform this counted case@>
	else if (ai->operand.wild_card >= EXTENSION_WILDCARD_BASE) @<Perform this lettered case@>
	else if (ai->operand.wild_card == TAMECARD)
		Actions::perform_inner(OUT, args, ai, ai->operand.specific_case, count++);
	else if (ai->operand.wild_card == REGEXP_WILDCARD) @<Perform this regular expressed case@>
	else if (ai->operand.wild_card == GROUP_WILDCARD) @<Perform this grouped case@>
	else @<Perform this matched case@>;

@<Perform this counted case@> =
	int find_count = 0;
	test_source *spi;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(spi, test_source, args->search_path)
		LOOP_OVER_LINKED_LIST(tc, test_case, spi->contents)
			if (find_count++ == ai->operand.wild_card - COUNT_WILDCARD_BASE) {
				Actions::perform_inner(OUT, args, ai, tc, count++);
				goto ExitCountSearch;
			}
	TEMPORARY_TEXT(M)
	if (find_count == 0)
		WRITE_TO(M, "there were no cases here at all");
	else
		WRITE_TO(M, "cases only run from ^1 to ^%d", find_count);
	Errors::fatal_with_text("%S", M);
	DISCARD_TEXT(M)
	ExitCountSearch: ;

@<Perform this lettered case@> =
	test_source *spi;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(spi, test_source, args->search_path)
		LOOP_OVER_LINKED_LIST(tc, test_case, spi->contents)
			if ((tc->format_reference == EXTENSION_FORMAT) &&
				(tc->letter_reference ==
					ai->operand.wild_card - EXTENSION_WILDCARD_BASE + 1)) {
				Actions::perform_inner(OUT, args, ai, tc, count++);
				goto ExitLetterSearch;
			}
	Errors::fatal("unable to find any such extension example");
	ExitLetterSearch: ;

@<Perform this regular expressed case@> =
	linked_list *matches = NEW_LINKED_LIST(test_case);
	RecipeFiles::find_cases_matching(matches, args->search_path, ai->operand.regexp_wild_card, FALSE);
	test_case *tc;
	LOOP_OVER_LINKED_LIST(tc, test_case, matches) {
		Actions::perform_inner(OUT, args, ai, tc, count++);
	}

@<Perform this grouped case@> =
	int scheduled = TRUE;
	TEMPORARY_TEXT(leafname)
	WRITE_TO(leafname, "%S.testgroup", ai->operand.regexp_wild_card);
	Str::delete_first_character(leafname);
	if (Str::get_first_char(leafname) == ':') {
		Str::delete_first_character(leafname);
		scheduled = FALSE;
	}
	filename *F = Filenames::in(args->groups_folder, leafname);
	linked_list *names_in_group = NEW_LINKED_LIST(text_stream);
	TextFiles::read(F, FALSE, "can't open test group file", TRUE,
		&Actions::read_group, NULL, names_in_group);
	DISCARD_TEXT(leafname)

	linked_list *matches = NEW_LINKED_LIST(test_case);
	text_stream *name;
	LOOP_OVER_LINKED_LIST(name, text_stream, names_in_group) {
		RecipeFiles::find_cases_matching(matches, args->search_path, name, TRUE);
	}
	test_case *tc;
	LOOP_OVER_LINKED_LIST(tc, test_case, matches) {
		ai->test_form = ai->action_type;
		if (scheduled) ai->action_type += SCHEDULED_TEST_ACTION;
		Actions::perform_inner(OUT, args, ai, tc, count++);
		if (scheduled) ai->action_type -= SCHEDULED_TEST_ACTION;
	}

@<Perform this matched case@> =
	test_source *spi;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(spi, test_source, args->search_path)
		LOOP_OVER_LINKED_LIST(tc, test_case, spi->contents)
			if (Actions::matches_wildcard(tc, ai->operand.wild_card)) {
				ai->test_form = ai->action_type;
				ai->action_type += SCHEDULED_TEST_ACTION;
				Actions::perform_inner(OUT, args, ai, tc, count++);
				ai->action_type -= SCHEDULED_TEST_ACTION;
			}

@

=
void Actions::read_group(text_stream *text, text_file_position *tfp, void *vm) {
	linked_list *matches = (linked_list *) vm;
	Str::trim_white_space(text);
	wchar_t c = Str::get_first_char(text);
	if ((c == 0) || (c == '#')) return;
	ADD_TO_LINKED_LIST(Str::duplicate(text), text_stream, matches);
}

@ And now we can forget everything about wild cards: we know for definite
which test case to work on.

=
void Actions::perform_inner(OUTPUT_STREAM, intest_instructions *args,
	action_item *ai, test_case *itc, int count) {
	text_stream *TO = OUT;
	text_stream TO_struct;
	if ((ai->action_type < SCHEDULED_TEST_ACTION) && (ai->redirection_filename)) {
		filename *F = ai->redirection_filename;
		if (itc) @<Expand NAME and NUMBER in the redirection filename@>;
		TO = &TO_struct;
		if (STREAM_OPEN_TO_FILE(TO, F, UTF8_ENC) == FALSE)
			Errors::fatal_with_file("unable to write file", F);
	}
	@<Finally do something, or at leask ask somebody else to@>;
	if ((ai->action_type < SCHEDULED_TEST_ACTION) && (ai->redirection_filename)) STREAM_CLOSE(TO);
}

@ If the leafname of the redirection file is |something_[NUMBER]| then we
substitute in the case number for |[NUMBER]|, and similarly for |[NAME]|.

@<Expand NAME and NUMBER in the redirection filename@> =
	TEMPORARY_TEXT(leaf)
	leaf = Str::duplicate(Filenames::get_leafname(F));
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, leaf, L"(%c*?)%[NAME%](%c*)")) {
		Str::clear(leaf);
		WRITE_TO(leaf, "%S%s%S", mr.exp[0], itc->test_case_name, mr.exp[1]);
	}
	while (Regexp::match(&mr, leaf, L"(%c*?)%[NUMBER%](%c*)")) {
		Str::clear(leaf);
		WRITE_TO(leaf, "%S%d%S", mr.exp[0], count, mr.exp[1]);
	}
	F = Filenames::in(Filenames::up(F), leaf);
	DISCARD_TEXT(leaf)
	Regexp::dispose_of(&mr);

@<Finally do something, or at leask ask somebody else to@> =
	switch (ai->action_type) {
		case CATALOGUE_ACTION:
			RecipeFiles::perform_catalogue(TO, args->search_path, NULL); break;
		case FIND_ACTION:
			RecipeFiles::perform_catalogue(TO, args->search_path, ai->assoc_text); break;
		case SOURCE_ACTION:
		case CONCORDANCE_ACTION:
			if (itc)
				Extractor::run(NULL, TO, itc, itc->test_location, itc->format_reference,
					itc->letter_reference, ai->action_type, NULL);
			break;
		case SCRIPT_ACTION:
			if (itc) {
				if (TextFiles::exists(itc->commands_location))
					Extractor::run(NULL, TO, itc, itc->commands_location, PLAIN_FORMAT,
						0, SOURCE_ACTION, NULL);
				else
					Extractor::run(NULL, TO, itc, itc->test_location, itc->format_reference,
						itc->letter_reference, ai->action_type, NULL);
			}
			break;
		case OPEN_ACTION:
			Shell::apply("open", itc->test_location); break;
		case BBDIFF_ACTION:
		case DIFF_ACTION:
		case TEST_ACTION:
		case DEBUGGER_ACTION:
		case BLESS_ACTION:
		case CURSE_ACTION:
		case SHOW_ACTION:
		case SHOW_I6_ACTION:
		case SHOW_TRANSCRIPT_ACTION:
		case REBLESS_ACTION:
			Tester::test(TO, itc, count, -1, ai->action_type); break;
		case REPORT_ACTION:
			Reporter::report_single(TO, itc, ai); break;
		case COMBINE_REPORTS_ACTION:
			Reporter::combine(TO, ai->assoc_number, ai->assoc_file1); break;
		case SKEIN_ACTION:
			Skeins::test_i7_skein(TO, ai->assoc_file1, ai->assoc_text); break;
		default:
			if (ai->action_type >= SCHEDULED_TEST_ACTION) {
				ai->action_type -= SCHEDULED_TEST_ACTION;
				Scheduler::schedule(itc, ai->redirection_filename, ai->test_form);
				ai->action_type += SCHEDULED_TEST_ACTION;
				break;
			}
			internal_error("unimplemented action");
	}
