[RecipeFiles::] Recipe Files.

To parse recipe files and/or using commands typed at the command line.

@h Recipe files.
A "recipe file" contains a mixture of "use commands" and "recipes"; the
former fill the universe of test cases, and the latter, which occupy the
bulk of the file, give recipes for how to conduct these test cases.

Recipe compilation is handled in Chapter 4. Here, we look after the use
commands and the syntac which divides them off from recipes, no more.

=
void RecipeFiles::read(filename *F, intest_instructions *args, char *err) {
	if (err) TextFiles::read(F, FALSE, err, TRUE, &RecipeFiles::scan, NULL, args);
	else TextFiles::read(F, FALSE, NULL, FALSE, &RecipeFiles::scan, NULL, args);
	text_file_position *tfp = NULL;
	@<Finish compiling any inline recipe which has ended@>;
}

void RecipeFiles::scan(text_stream *line_text, text_file_position *tfp, void *vargs) {
	intest_instructions *args = vargs;
	@<Continue compiling any inline recipe@>;

	int no_line_tokens = 0;
	text_stream **line_tokens = NULL;
	
	@<Tokenise this line@>;
	@<If the line defines a new recipe, inline or external, compile that@>;
	@<Otherwise execute the line as a sequence of use commands@>;
}

@ It would be nicer to store these tokens in a linked list of unbounded
size, rather than a bounded array, but this makes it easier to share code
with the routine parsing the command line. In any case, nobody will hit:

@d MAX_LINE_TOKENS 128

@<Tokenise this line@> =	
	line_tokens = Memory::calloc(MAX_LINE_TOKENS, sizeof(text_stream *),
		COMMAND_HISTORY_MREASON);

	string_position pos = Str::start(line_text);
	while (TRUE) {
		while (Regexp::white_space(Str::get(pos))) pos = Str::forward(pos);
		inchar32_t c = Str::get(pos);
		if ((c == 0) || (c == '!')) break;

		if (no_line_tokens == MAX_LINE_TOKENS) {
			Errors::in_text_file("line has too many tokens", tfp); return;
		}

		text_stream *tok = Str::new();
		if (Str::get(pos) == '\'') {
			pos = Str::forward(pos);
			int escaped = FALSE;
			while ((Str::get(pos)) && ((escaped == FALSE) && (Str::get(pos) != '\''))) {
				escaped = FALSE;
				if (Str::get(pos) == '\\') escaped = TRUE;
				PUT_TO(tok, Str::get(pos));
				pos = Str::forward(pos);
			}
			if (Str::get(pos) == '\'') pos = Str::forward(pos);
		} else {
			while ((Str::get(pos)) && (!Regexp::white_space(Str::get(pos)))) {
				PUT_TO(tok, Str::get(pos));
				pos = Str::forward(pos);
			}
		}
		line_tokens[no_line_tokens++] = tok;
	}

@<If the line defines a new recipe, inline or external, compile that@> =
	if ((no_line_tokens > 0) && (Str::eq(line_tokens[0], I"-recipe"))) {
		text_stream *name = I"[Recipe]";
		int pos = 1, ext = FALSE;
		if ((no_line_tokens > pos) &&
			(Str::get_first_char(line_tokens[pos]) == '[') &&
			(Str::get_last_char(line_tokens[pos]) == ']'))
			name = line_tokens[pos++];
		if (no_line_tokens > pos) {
			TEMPORARY_TEXT(delia)
			RecipeFiles::expand(delia, line_tokens[pos++]);
			recipe *R = Delia::compile(Filenames::from_text(delia), name); ext = TRUE;
			DISCARD_TEXT(delia)
			if (R == NULL) {
				Errors::in_text_file("recipe failed to compile", tfp); return;
			}
		}
		if (no_line_tokens != pos) {
			Errors::in_text_file("malformed -recipe", tfp); return;
		}
		if (ext == FALSE) @<Begin compiling an inline recipe@>;
		return;
	}

@<Otherwise execute the line as a sequence of use commands@> =
	RecipeFiles::read_using_instructions(args, 0, no_line_tokens, line_tokens, args->home);

@<Begin compiling an inline recipe@> =
	args->compiling_recipe = Delia::begin_compilation(name);

@<Continue compiling any inline recipe@> =
	if (args->compiling_recipe) {
		Delia::compile_line(line_text, tfp, (void *) args->compiling_recipe);
		@<Finish compiling any inline recipe which has ended@>;
		return;
	}

@<Finish compiling any inline recipe which has ended@> =
	if (args->compiling_recipe) 
		if (args->compiling_recipe->end_found) {
			recipe *R = Delia::end_compilation(args->compiling_recipe);
			args->compiling_recipe = NULL;
			if (R == NULL) {
				Errors::in_text_file("recipe failed to compile", tfp); return;
			}
		}

@h Reading the use command block.
The following parses and acts upon a series of use command tokens. Though
the prototype of the function looks like something which only parses a
chunk of the command line, in fact it also parses lines of tokens from
recipe files (see above).

At any rate, we have a line to tokens |USE1 USE2 ...USEn|, somewhere in
the array |argv|. |from_arg_n| is the index of |USE1|, and |to_arg_n| is
the index after |USEn|.

=
void RecipeFiles::read_using_instructions(intest_instructions *args,
	int from_arg_n, int to_arg_n, text_stream **argv, pathname *project) {
	int t = NO_SPT, multiple = FALSE, allowed_to_execute = TRUE,
		allowed_not_to_exist = FALSE;
	TEMPORARY_TEXT(recipe_name)
	WRITE_TO(recipe_name, "[Recipe]");
	@<Log the using instructions@>;
	for (int i=from_arg_n; i<to_arg_n; i++) {
		text_stream *opt = argv[i];
		
		@<Act on if or endif@>;
		@<Act on set@>;
		@<Act on groups@>;
		@<Act on singular@>;
		@<Act on a case type choice@>;
		@<Act on a recipe choice@>;

		filename *F = NULL;
		pathname *P = NULL;
		TEMPORARY_TEXT(expanded)
		RecipeFiles::expand(expanded, opt);
		if (multiple) P = Pathnames::from_text(expanded);
		else F = Filenames::from_text(expanded);
		DISCARD_TEXT(expanded)
		if (allowed_not_to_exist) {
			if ((P) && (Directories::exists(P) == FALSE)) continue;
			if ((F) && (TextFiles::exists(F) == FALSE)) continue;
		}
		if (t == NO_SPT) @<Load in a file of further using instructions@>
		else @<Execute this as a using instruction@>;
	}
	DISCARD_TEXT(recipe_name)
}

@<Log the using instructions@> =
	if (Log::aspect_switched_on(INSTRUCTIONS_DA)) {
		LOG("using:");
		for (int i=from_arg_n; i<to_arg_n; i++) LOG(" %S", argv[i]);
		LOG("\n");
	}

@<Act on if or endif@> =
	if ((Str::eq(opt, I"-if")) && (i+1<to_arg_n)) {
		allowed_to_execute = Str::eq_insensitive(argv[i+1], Globals::get_platform());
		LOGIF(INSTRUCTIONS,
			"using: -if %S (platform %S): %s\n", argv[i+1], Globals::get_platform(),
				allowed_to_execute?"yes":"no");
		i++; continue;
	}
	if (Str::eq_wide_string(opt, U"-endif")) { allowed_to_execute = TRUE; continue; }
	if (allowed_to_execute == FALSE) continue;

@<Act on set@> =
	if ((Str::eq_wide_string(opt, U"-set")) && (i+2<to_arg_n)) {
		Globals::create(argv[i+1]);
		Globals::set(argv[i+1], argv[i+2]);
		i += 2; continue;
	}

@<Act on groups@> =
	if ((Str::eq_wide_string(opt, U"-groups")) && (i+1<to_arg_n)) {
		args->groups_folder = Pathnames::from_text(argv[i+1]);
		i++; continue;
	}

@<Act on singular@> =
	if ((Str::eq_wide_string(opt, U"-singular")) && (i+1<to_arg_n)) {
		dictionary *D = args->singular_case_names;
		WRITE_TO(Dictionaries::create_text(D, argv[i+1]), "1");
		i++; continue;
	}

@<Act on a case type choice@> =
	if (Str::eq(opt, I"-extension")) { t = EXTENSION_SPT; continue; }
	else if (Str::eq(opt, I"-annotated-extension")) { t = EXTENSION_SPT; continue; }
	else if (Str::eq(opt, I"-case")) { t = CASE_SPT; continue; }
	else if (Str::eq(opt, I"-annotated-case")) { t = ANNOTATED_CASE_SPT; continue; }
	else if (Str::eq(opt, I"-problem")) { t = PROBLEM_SPT; continue; }
	else if (Str::eq(opt, I"-annotated-problem")) { t = ANNOTATED_PROBLEM_SPT; continue; }
	else if (Str::eq(opt, I"-example")) { t = EXAMPLE_SPT; continue; }
	else if (Str::eq(opt, I"-annotated-example")) { t = EXAMPLE_SPT; continue; }

	else if (Str::eq(opt, I"-extensions")) { t = EXTENSION_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-annotated-extensions")) { t = EXTENSION_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-cases")) { t = CASE_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-annotated-cases")) { t = ANNOTATED_CASE_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-problems")) { t = PROBLEM_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-annotated-problems")) { t = ANNOTATED_PROBLEM_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-examples")) { t = EXAMPLE_SPT; multiple = TRUE; continue; }
	else if (Str::eq(opt, I"-annotated-examples")) { t = EXAMPLE_SPT; multiple = TRUE; continue; }

	else if (Str::eq(opt, I"-possible-extension")) { t = EXTENSION_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-extension")) { t = EXTENSION_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-case")) { t = CASE_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-case")) { t = ANNOTATED_CASE_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-problem")) { t = PROBLEM_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-problem")) { t = ANNOTATED_PROBLEM_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-example")) { t = EXAMPLE_SPT; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-example")) { t = EXAMPLE_SPT; allowed_not_to_exist = TRUE; continue; }

	else if (Str::eq(opt, I"-possible-extensions")) { t = EXTENSION_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-extensions")) { t = EXTENSION_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-cases")) { t = CASE_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-cases")) { t = ANNOTATED_CASE_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-problems")) { t = PROBLEM_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-problems")) { t = ANNOTATED_PROBLEM_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-examples")) { t = EXAMPLE_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::eq(opt, I"-possible-annotated-examples")) { t = EXAMPLE_SPT; multiple = TRUE; allowed_not_to_exist = TRUE; continue; }
	else if (Str::get_first_char(opt) == '-') Errors::fatal_with_text("unrecognised -using case type: '%S'", opt);

@<Act on a recipe choice@> =
	if ((Str::get_first_char(opt) == '[') && (Str::get_last_char(opt) == ']')) {
		Str::copy(recipe_name, opt); continue;
	}

@<Load in a file of further using instructions@> =
	RecipeFiles::read(F, args, "can't open using instructions file");

@<Execute this as a using instruction@> =
	linked_list *cases_within = NEW_LINKED_LIST(test_case);

	if (multiple) RecipeFiles::scan_directory_for_cases(cases_within, t, P, project, recipe_name);
	else RecipeFiles::scan_file_for_cases(cases_within, t, F, recipe_name);

	if (LinkedLists::len(cases_within) > 0) @<Create a search path item@>;

@h Search path items.
Each of these represents a place in the file system where test cases may
be found: either as a specific file, or a directory. It also comes with
a "search path type", telling Intest how the test case will be stored.
There are five basic search path types:

@e NO_SPT from 0
@e EXTENSION_SPT
@e CASE_SPT
@e ANNOTATED_CASE_SPT
@e PROBLEM_SPT
@e ANNOTATED_PROBLEM_SPT
@e EXAMPLE_SPT

=
typedef struct test_source {
	int search_path_type; /* one of the |_SPT| cases above */
	int multiple; /* is this a pathname to a folder? */
	struct filename *exactly_this;
	struct pathname *within_this;
	struct linked_list *contents; /* of |test_case| */
	CLASS_DEFINITION
} test_source;

@<Create a search path item@> =
	test_source *spi = CREATE(test_source);
	spi->search_path_type = t;
	spi->multiple = multiple;
	spi->within_this = P;
	spi->exactly_this = F;
	spi->contents = cases_within;
	ADD_TO_LINKED_LIST(spi, test_source, args->search_path);

@ =
test_case *RecipeFiles::find_case(intest_instructions *args, text_stream *name) {
	test_source *spi;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(spi, test_source, args->search_path)
		LOOP_OVER_LINKED_LIST(tc, test_case, spi->contents)
			if (Str::eq(tc->test_case_name, name))
				return tc;
	return NULL;
}

@ =
text_stream *RecipeFiles::case_type_as_text(int spt) {
	switch (spt) {
		case EXTENSION_SPT: return I"extension";
		case CASE_SPT: return I"case";
		case ANNOTATED_CASE_SPT: return I"case";
		case ANNOTATED_PROBLEM_SPT: return I"problem";
		case PROBLEM_SPT: return I"problem";
		case EXAMPLE_SPT: return I"example";
	}
	return I"unknown";
}

@h Expanding filenames and pathnames.

=
void RecipeFiles::expand(OUTPUT_STREAM, text_stream *from) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, from, U"%$%$([A-Za-z]+)(%c*)")) {
		WRITE("%S%S", Globals::get(mr.exp[0]), mr.exp[1]);
	} else {
		WRITE("%S", from);
	}
	Regexp::dispose_of(&mr);
}

@h Scanning and extracting.
The following looks for all the test cases it can find in a directory |P|.

=
void RecipeFiles::scan_directory_for_cases(linked_list *L,
	int t, pathname *P, pathname *project, text_stream *rn) {
	scan_directory *FOLD = Directories::open(P);
	if (FOLD == NULL) Errors::fatal_with_path("unable to open test cases folder", P);
	TEMPORARY_TEXT(leafname)
	while (Directories::next(FOLD, leafname)) {
		inchar32_t first = Str::get_first_char(leafname), last = Str::get_last_char(leafname);
		if (Platform::is_folder_separator(last)) continue;
		if (first == '.') continue;
		if (first == '(') continue;
		if ((first == '-') ||
			(first == '[') ||
			(Actions::identify_wildcard(leafname) != TAMECARD))
			Errors::fatal_with_text("no test can legally be called '%S'", leafname);
		if (Str::includes(leafname, I"--")) continue;
		filename *F = Filenames::in(P, leafname);
		RecipeFiles::scan_file_for_cases(L, t, F, rn);
	}
	DISCARD_TEXT(leafname)
	Directories::close(FOLD);
}

@ And this in turn is called when one or more test cases are to be extracted
from a specific single file. (Note that a single Inform 7 extension file can
contain multiple examples, each generating a test case, so it really can be
more than one.)

=
filename *extraction_file = NULL;
void RecipeFiles::scan_file_for_cases(linked_list *L, int t, filename *F, text_stream *rn) {
	switch (t) {
		case EXTENSION_SPT: @<Adopt Example cases from an extension file@>;
		case ANNOTATED_CASE_SPT:
			@<Adopt a single test case needing extraction@>;
		case ANNOTATED_PROBLEM_SPT:
			@<Adopt a single problem case needing extraction@>;
		case CASE_SPT: case PROBLEM_SPT:
			@<Adopt a single test case not needing extraction@>;
		case EXAMPLE_SPT: @<Adopt Example cases from an example file@>;
		default: internal_error("bad search path type");
	}	
}

@<Adopt a single test case not needing extraction@> =
	test_case *tc = RecipeFiles::new_case(t, F, PLAIN_FORMAT, 0, NULL, rn);
	ADD_TO_LINKED_LIST(tc, test_case, L);
	break;

@<Adopt Example cases from an extension file@> =
	extraction_file = F;
	Extractor::run(L, NULL, NULL, F, EXTENSION_FORMAT, 0, CENSUS_ACTION, rn);
	break;

@<Adopt Example cases from an example file@> =
	extraction_file = F;
	Extractor::run(L, NULL, NULL, F, EXAMPLE_FORMAT, 0, CENSUS_ACTION, rn);
	break;

@<Adopt a single test case needing extraction@> =
	extraction_file = F;
	Extractor::run(L, NULL, NULL, F, ANNOTATED_FORMAT, 0, CENSUS_ACTION, rn);
	break;

@<Adopt a single problem case needing extraction@> =
	extraction_file = F;
	Extractor::run(L, NULL, NULL, F, ANNOTATED_PROBLEM_FORMAT, 0, CENSUS_ACTION, rn);
	break;

@ These functions are called by the Extractor when it finds a test case in
the relevant example or extension file. (Those are both Inform 7-only
features.)

=
test_case *RecipeFiles::observe_in_extension(linked_list *L, int count, text_stream *force_vm, text_stream *rn) {
	test_case *tc = RecipeFiles::new_case(EXTENSION_SPT, extraction_file, EXTENSION_FORMAT, count, force_vm, rn);
	if (L) ADD_TO_LINKED_LIST(tc, test_case, L);
	return tc;
}

test_case *RecipeFiles::observe_in_example(linked_list *L, text_stream *force_vm, text_stream *rn) {
	test_case *tc = RecipeFiles::new_case(EXAMPLE_SPT, extraction_file, EXAMPLE_FORMAT, 0, force_vm, rn);
	if (L) ADD_TO_LINKED_LIST(tc, test_case, L);
	return tc;
}

test_case *RecipeFiles::observe_in_annotated_case(linked_list *L, text_stream *force_vm, text_stream *rn) {
	test_case *tc = RecipeFiles::new_case(ANNOTATED_CASE_SPT, extraction_file, ANNOTATED_FORMAT, 0, force_vm, rn);
	if (L) ADD_TO_LINKED_LIST(tc, test_case, L);
	return tc;
}

test_case *RecipeFiles::observe_in_annotated_problem(linked_list *L, text_stream *force_vm, text_stream *rn) {
	test_case *tc = RecipeFiles::new_case(PROBLEM_SPT, extraction_file, ANNOTATED_PROBLEM_FORMAT, 0, force_vm, rn);
	if (L) ADD_TO_LINKED_LIST(tc, test_case, L);
	return tc;
}

@h Test cases.
The content of a test case lives in a single file, but may live in only part
of that file. The file can have three possible formats, though two of them
arise only for Inform 7.

@d PLAIN_FORMAT 1 /* the file as a whole is one case */
@d EXAMPLE_FORMAT 2 /* Inform example file discussing code which forms one case */
@d EXTENSION_FORMAT 3 /* Inform extension file containing examples A, B, C, ... */
@d ANNOTATED_FORMAT 4 /* test case, but with metadata key-value pairs first */
@d ANNOTATED_PROBLEM_FORMAT 5 /* the same, but for a problem case */

@d MAX_METADATA_PAIRS 10

=
typedef struct test_case {
	struct filename *test_location;
	int format_reference; /* one of the |_FORMAT| constants above */
	int letter_reference; /* 1 for A, 2 for B, ..., or 0 for none */

	struct text_stream *test_case_name;
	struct text_stream *test_case_title;
	struct text_stream *test_recipe_name; /* such as |[Recipe]| */
	int test_type; /* one of the |_SPT| constants above */
	int cursed; /* currently has no ideal output to test against */
	struct text_stream *known_hash; /* md5 hash of known-correct code */
	int no_kv_pairs;
	struct text_stream *keys[MAX_METADATA_PAIRS];
	struct text_stream *values[MAX_METADATA_PAIRS];
	
	struct pathname *work_area;
	struct filename *commands_location;
	int test_me_detected;
	int command_line_echoing_detected;
	int left_bracket, right_bracket;
	
	struct text_stream *HTML_report;
	CLASS_DEFINITION
} test_case;

@ =
test_case *RecipeFiles::new_case(int t, filename *F, int fref, int ref,
	text_stream *force_vm, text_stream *recipe_name) {
	test_case *tc = CREATE(test_case);
	tc->test_case_name = Str::new();
	Filenames::write_unextended_leafname(tc->test_case_name, F);
	if (ref > 0) WRITE_TO(tc->test_case_name, " Example %c", 'A'+ref-1);
	tc->test_case_title = NULL;
	tc->test_recipe_name = Str::duplicate(recipe_name);
	tc->test_type = t;
	tc->test_location = F;
	filename *G = F;
	tc->work_area = Filenames::up(F);
	if (t == EXTENSION_SPT) {
		pathname *P = Globals::to_pathname(I"extensions_testing_area");
		if (P) {
			TEMPORARY_TEXT(leaf)
			WRITE_TO(leaf, "%S.txt", tc->test_case_name);
			G = Filenames::in(P, leaf);
			DISCARD_TEXT(leaf)
			tc->work_area = P;
		}
	}

	filename *DG = Filenames::set_extension(G, I"txt");
	TEMPORARY_TEXT(cs)
	Filenames::write_unextended_leafname(cs, DG);
	WRITE_TO(cs, "--S.txt");
	tc->commands_location = Filenames::in(Filenames::up(DG), cs);
	DISCARD_TEXT(cs)
	tc->format_reference = fref;
	tc->letter_reference = ref;
	tc->test_me_detected = FALSE;
	tc->command_line_echoing_detected = FALSE;
	tc->cursed = FALSE;
	tc->known_hash = NULL;
	tc->left_bracket = '{'; tc->right_bracket = '}';
	tc->no_kv_pairs = 0;
	tc->HTML_report = NULL;
	return tc;
}

void RecipeFiles::NameTestCase(test_case *tc, text_stream *title) {
	if (tc == NULL) internal_error("naming null test case");
	tc->test_case_title = Str::duplicate(title);
}

void RecipeFiles::AddKVPair(test_case *tc, text_stream *key, text_stream *value) {
	if ((tc) && (tc->no_kv_pairs < MAX_METADATA_PAIRS-1)) {
		text_stream *add_value = Str::duplicate(value);
		LOOP_THROUGH_TEXT(pos, add_value)
			if (Str::get(pos) == DELIA_QUOTE_CHARACTER)
				Str::put(pos, SHELL_QUOTE_CHARACTER);
		tc->keys[tc->no_kv_pairs] = Str::duplicate(key);
		tc->values[tc->no_kv_pairs] = add_value;
		tc->no_kv_pairs++;
	}
}

@ The following is the back end for the |-find| do action, and lists all
test cases whose names or titles match a given regular expression. If the
|match| expression is empty, it lists everything in the search list.

@d MAX_NAME_MATCH_LENGTH 1024

=
void RecipeFiles::perform_catalogue(OUTPUT_STREAM, linked_list *sources, text_stream *match) {
	if (Str::len(match) > 0) WRITE("Test cases matching '%S':\n", match);
	linked_list *matches = NEW_LINKED_LIST(test_case);
	RecipeFiles::find_cases_matching(matches, sources, NULL, match, FALSE);
	int n = 0;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(tc, test_case, matches) {
		WRITE("%S%s", tc->test_case_name, (tc->test_type == PROBLEM_SPT)?" (problem)":"");
		if (Str::len(tc->test_case_title) > 0) WRITE(" = %S", tc->test_case_title);
		WRITE("\n");
		n++;
	}
	if (n == 0) WRITE("(none)\n");
}

@ Which employs:

=
void RecipeFiles::find_cases_matching(linked_list *matches, linked_list *sources,
	text_stream *key, text_stream *match, int exactly) {
	TEMPORARY_TEXT(re)
	if (exactly) {
		WRITE_TO(re, "%S", match);
	} else {
		WRITE_TO(re, "%%c*%S%%c*", match);
	}
	inchar32_t wregexp[MAX_NAME_MATCH_LENGTH];
	Str::copy_to_wide_string(wregexp, re, MAX_NAME_MATCH_LENGTH);
	DISCARD_TEXT(re)
	match_results mr2 = Regexp::create_mr();
	test_source *spi;
	test_case *tc;
	LOOP_OVER_LINKED_LIST(spi, test_source, sources)
		LOOP_OVER_LINKED_LIST(tc, test_case, spi->contents) {
			if ((tc->format_reference != ANNOTATED_FORMAT) &&
				(tc->format_reference != EXAMPLE_FORMAT) &&
				(tc->format_reference != EXTENSION_FORMAT))
				Extractor::run(NULL, NULL,
					tc, tc->test_location, tc->format_reference, 0, CENSUS_ACTION, NULL);
			int pass = FALSE;
			if (match == NULL) pass = TRUE;
			if (key == NULL) {
				if ((Regexp::match(&mr2, tc->test_case_name, wregexp)) ||
					(Regexp::match(&mr2, tc->test_case_title, wregexp))) pass = TRUE;
			} else if (Str::eq_insensitive(key, I"NAME")) {
				if (Regexp::match(&mr2, tc->test_case_name, wregexp)) pass = TRUE;
			} else if (Str::eq_insensitive(key, I"TITLE")) {
				if (Regexp::match(&mr2, tc->test_case_title, wregexp)) pass = TRUE;
			} else {
				for (int i=0; i<tc->no_kv_pairs; i++)
					if (Str::eq_insensitive(key, tc->keys[i]))
						if (Regexp::match(&mr2, tc->values[i], wregexp)) pass = TRUE;
			}
			if (pass) {
				ADD_TO_LINKED_LIST(tc, test_case, matches);
			}
		}
	Regexp::dispose_of(&mr2);
}
