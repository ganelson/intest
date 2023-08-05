[Delia::] The Delia Compiler.

To compile a recipe for how to perform a test.

@h Instruction set.
Intest recipes are written in a mini-language called Delia, which has a fixed
set of commands, enumerated as follows.

@e COPY_RCOM from 1
@e DEBUGGER_RCOM
@e DEFAULT_RCOM
@e ELSE_RCOM
@e ENDIF_RCOM
@e EXISTS_RCOM
@e EXTRACT_RCOM
@e FAIL_RCOM
@e FAIL_STEP_RCOM
@e HASH_RCOM
@e IF_RCOM
@e IFDEF_RCOM
@e IFNDEF_RCOM
@e IF_EXISTS_RCOM
@e MATCH_BINARY_RCOM
@e MATCH_FOLDER_RCOM
@e MATCH_G_TRANSCRIPT_RCOM
@e MATCH_I6_TRANSCRIPT_RCOM
@e MATCH_PROBLEM_RCOM
@e MATCH_TEXT_RCOM
@e MATCH_PLATFORM_TEXT_RCOM
@e MATCH_Z_TRANSCRIPT_RCOM
@e MKDIR_RCOM
@e OR_RCOM
@e PASS_RCOM
@e SET_RCOM
@e SHOW_RCOM
@e STEP_RCOM

@ And here's some metadata about them:

=
typedef struct recipe_command {
	int rc_code; /* one of the |*_RCOM| codes below */
	wchar_t *keyword;
	int tokens_required; /* or negative for "any number, including none" */
	int supports_or; /* an |or:| command can follow */
	int changes_nesting;
} recipe_command;

recipe_command instruction_set[] = {
	{ COPY_RCOM, L"copy", 2, FALSE, 0 },
	{ DEBUGGER_RCOM, L"debugger", -1, TRUE, 0 },
	{ DEFAULT_RCOM, L"default", -1, FALSE, 0 },
	{ ELSE_RCOM, L"else", 0, FALSE, 0 },
	{ ENDIF_RCOM, L"endif", 0, FALSE, -1 },
	{ EXISTS_RCOM, L"exists", 1, TRUE, 0 },
	{ EXTRACT_RCOM, L"extract", 2, FALSE, 0 },
	{ FAIL_RCOM, L"fail", 1, FALSE, 0 },
	{ FAIL_STEP_RCOM, L"fail step", -1, TRUE, 0 },
	{ HASH_RCOM, L"hash", 2, TRUE, 0 },
	{ IF_RCOM, L"if", 2, FALSE, 1 },
	{ IFDEF_RCOM, L"ifdef", 1, FALSE, 1 },
	{ IFNDEF_RCOM, L"ifndef", 1, FALSE, 1 },
	{ IF_EXISTS_RCOM, L"if exists", 1, FALSE, 1 },
	{ MATCH_BINARY_RCOM, L"match binary", 2, TRUE, 0 },
	{ MATCH_FOLDER_RCOM, L"match folder", 2, TRUE, 0 },
	{ MATCH_G_TRANSCRIPT_RCOM, L"match glulxe transcript", 2, TRUE, 0 },
	{ MATCH_I6_TRANSCRIPT_RCOM, L"match i6 transcript", 2, TRUE, 0 },
	{ MATCH_PROBLEM_RCOM, L"match problem", 2, TRUE, 0 },
	{ MATCH_TEXT_RCOM, L"match text", 2, TRUE, 0 },
	{ MATCH_PLATFORM_TEXT_RCOM, L"match platform text", 2, TRUE, 0 },
	{ MATCH_Z_TRANSCRIPT_RCOM, L"match frotz transcript", 2, TRUE, 0 },
	{ MKDIR_RCOM, L"mkdir", 1, FALSE, 0 },
	{ OR_RCOM, L"or", -1, FALSE, 0 },
	{ PASS_RCOM, L"pass", 1, FALSE, 0 },
	{ SET_RCOM, L"set", -1, FALSE, 0 },
	{ SHOW_RCOM, L"show", -1, TRUE, 0 },
	{ STEP_RCOM, L"step", -1, TRUE, 0 },
	{ -1, NULL, 0, FALSE, 0 }
};

@h Recipes in memory.
Are stored in the following hierarchy, with a recipe being essentially a
linked list of lines, and a line being essentially a linked list of tokens.

=
typedef struct recipe {
	struct filename *compiled_from;
	struct linked_list *lines; /* of |recipe_line| */
	struct text_stream *recipe_name;
	int compilation_errors;
	int conditional_nesting;
	int end_found;
	struct recipe_command *last_command;
	CLASS_DEFINITION
} recipe;

typedef struct recipe_line {
	struct recipe_command *command_used;
	struct linked_list *recipe_tokens; /* of |recipe_token| */
	struct text_stream *from_text;
	CLASS_DEFINITION
} recipe_line;

typedef struct recipe_token {
	struct text_stream *token_text;
	int token_quoted;
	int token_indirects_to_file;
	int token_indirects_to_hash;
	CLASS_DEFINITION
} recipe_token;

@ =
void Delia::log_line(OUTPUT_STREAM, void *vL) {
	recipe_line *L = (recipe_line *) vL;
	WRITE("%S", L->from_text);
}

@ This looks slow, but there are unlikely to be more than five or so recipes
loaded at once.

=
recipe *Delia::find(text_stream *name) {
	recipe *R;
	LOOP_OVER(R, recipe)
		if (Str::eq(name, R->recipe_name))
			return R;
	return NULL;
}

@h Compilation.
The compiler is correspondingly hierarchical. Note that we return only validly
compiled recipes.

=
recipe *Delia::compile(filename *F, text_stream *name) {
	recipe *R = Delia::begin_compilation(name);
	R->compiled_from = F;
	TextFiles::read(F, FALSE, "unable to read recipe file: %f", TRUE,
		&Delia::compile_line, NULL, (void *) R);
	return Delia::end_compilation(R);
}

@ =
recipe *Delia::begin_compilation(text_stream *name) {
	recipe *R = CREATE(recipe);
	R->lines = NEW_LINKED_LIST(recipe_line);
	R->compilation_errors = FALSE;
	R->compiled_from = NULL;
	R->conditional_nesting = 0;
	R->recipe_name = Str::duplicate(name);
	R->end_found = FALSE;
	return R;
}

recipe *Delia::end_compilation(recipe *R) {
	if (R->conditional_nesting > 0) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "'endif' missing at end of recipe");
		Errors::in_text_file_S(ERM, NULL);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	}
	if (R->compilation_errors) return NULL;
	return R;
}

@ We skip blank lines and comments, then split the line as a command plus some
tokens. The divider is a colon, which is optional (in which case, no tokens).

=
void Delia::compile_line(text_stream *text, text_file_position *tfp, void *state) {
	recipe *R = (recipe *) state;
	match_results mr = Regexp::create_mr();
	if ((Regexp::string_is_white_space(text)) || (Regexp::match(&mr, text, L" *!%c*"))) {
		;
	} else if (Regexp::match(&mr, text, L" *-end *")) {
		R->end_found = TRUE;
	} else if (Regexp::match(&mr, text, L" *(%c*?): *(%c*)")) {
		Delia::compile_command(R, text, mr.exp[0], mr.exp[1], tfp);
	} else if (Regexp::match(&mr, text, L" *(%c*?)")) {
		Delia::compile_command(R, text, mr.exp[0], Str::new(), tfp);
	}
	Regexp::dispose_of(&mr);
}

@ The command has to be in the instruction set, and the number of tokens
has to be reasonable, but otherwise anything goes.

=
void Delia::compile_command(recipe *R, text_stream *text,
	text_stream *command, text_stream *tokens, text_file_position *tfp) {
	recipe_command *rc = NULL;
	for (int i=0; ; i++)
		if (instruction_set[i].keyword == NULL)
			break;
		else {
			if (Str::eq_wide_string(command, instruction_set[i].keyword))
				rc = &instruction_set[i];
		}
	if (rc == NULL) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "unknown recipe command '%S'", command);
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	} else {
		recipe_line *L = CREATE(recipe_line);
		L->command_used = rc;
		L->recipe_tokens = NEW_LINKED_LIST(recipe_token);
		L->from_text = Str::duplicate(text);
		Delia::tokenise(L->recipe_tokens, tokens);

		@<Make sure the number of tokens is reasonable@>;
		if (rc->rc_code == OR_RCOM) @<Make sure the or is allowed@>;
		if ((rc->rc_code == SET_RCOM) || (rc->rc_code == DEFAULT_RCOM))
			@<Make sure the set is well-formatted@>;
		if ((rc->rc_code == IFDEF_RCOM) || (rc->rc_code == IFNDEF_RCOM))
			@<Make sure the ifdef is well-formatted@>;
		if (rc->rc_code == IF_RCOM) @<Make sure the if is well-formatted@>;
		if (rc->rc_code == SHOW_RCOM) @<Make sure the show is well-formatted@>;
		R->conditional_nesting += rc->changes_nesting;
		@<Make sure the conditional nesting is allowed@>;

		R->last_command = rc;
		ADD_TO_LINKED_LIST(L, recipe_line, R->lines);
	}
}

@<Make sure the number of tokens is reasonable@> =
	int n = 0;
	recipe_token *T;
	LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens) n++;

	if ((rc->tokens_required >= 0) && (n != rc->tokens_required)) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "recipe command '%S' takes %d token(s), but %d found",
			command, rc->tokens_required, n);
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	}

@<Make sure the or is allowed@> =
	if (R->last_command == NULL) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "'or' can't be the first command");
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	} else if (R->last_command->supports_or == FALSE) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "'or' can't follow a '%w' command", R->last_command->keyword);
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	}

@<Make sure the set is well-formatted@> =
	int n = 0;
	recipe_token *T;
	LOOP_OVER_LINKED_LIST(T, recipe_token, L->recipe_tokens) n++;
	if (n == 0) {
		Errors::in_text_file("nothing to set", tfp);
		R->compilation_errors = TRUE;
	} else {
		recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
		recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
		text_stream *K = first->token_text;
		if (Str::get_first_char(K) == '$') {
			Str::delete_first_character(K);
			if ((n < 2) || (Str::eq(second->token_text, I"=") == FALSE)) {
				Errors::in_text_file("no '=' in set command", tfp);
				R->compilation_errors = TRUE;
			} else {
				DELETE_FROM_LINKED_LIST(1, recipe_token, L->recipe_tokens);
			}
		} else {
			TEMPORARY_TEXT(ERM)
			WRITE_TO(ERM, "set target '%S' doesn't begin with '$'", K);
			Errors::in_text_file_S(ERM, tfp);
			DISCARD_TEXT(ERM)
			R->compilation_errors = TRUE;
		}
	}

@<Make sure the if is well-formatted@> =
	recipe_token *second = ENTRY_IN_LINKED_LIST(1, recipe_token, L->recipe_tokens);
	text_stream *K = second->token_text;
	if ((Str::get_first_char(K) == DELIA_QUOTE_CHARACTER) &&
		(Str::get_last_char(K) == DELIA_QUOTE_CHARACTER)) {
		Str::delete_first_character(K);
		Str::delete_last_character(K);
	}

@<Make sure the ifdef is well-formatted@> =
	recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
	text_stream *K = first->token_text;
	if (Str::get_first_char(K) == '$') {
		Str::delete_first_character(K);
	} else {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "ifdef test '%S' doesn't begin with '$'", K);
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
	}

@<Make sure the show is well-formatted@> =
	switch (LinkedLists::len(L->recipe_tokens)) {
		case 1: break;
		case 2: {
			recipe_token *first = ENTRY_IN_LINKED_LIST(0, recipe_token, L->recipe_tokens);
			text_stream *K = first->token_text;
			int bad = FALSE;
			LOOP_THROUGH_TEXT(pos, K) {
				wchar_t c = Str::get(pos);
				if (((c < 'a') || (c > 'z')) && ((c < '0') || (c > '9')) && (c != '-'))
					bad = TRUE;
			}
			if (bad) {
				TEMPORARY_TEXT(ERM)
				WRITE_TO(ERM, "'show' item '%S' should contain only lower-case "
					"letters, digits and dashes", K);
				Errors::in_text_file_S(ERM, tfp);
				DISCARD_TEXT(ERM)
				R->compilation_errors = TRUE;
			}
			break;
		}
		default: {
			Errors::in_text_file_S(I"'show' must take 1 or 2 tokens", tfp);
			R->compilation_errors = TRUE;
			break;
		}
	}

@<Make sure the conditional nesting is allowed@> =
	if ((R->conditional_nesting < 0) ||
		((R->conditional_nesting == 0) && (rc->rc_code == ELSE_RCOM))) {
		TEMPORARY_TEXT(ERM)
		WRITE_TO(ERM, "'%w' misplaced", rc->keyword);
		Errors::in_text_file_S(ERM, tfp);
		DISCARD_TEXT(ERM)
		R->compilation_errors = TRUE;
		R->conditional_nesting -= rc->changes_nesting;
	}

@ The lowest level of the compiler is the tokeniser, which breaks up a
string at white space boundaries, except within the shell quote character.

@d DELIA_QUOTE_CHARACTER '\''

=
void Delia::tokenise(linked_list *L, text_stream *txt) {
	string_position P = Str::start(txt);
	while (Characters::is_space_or_tab(Str::get(P))) P = Str::forward(P);
	wchar_t first = Str::get(P);
	if (first == 0) return;

	recipe_token *T = CREATE(recipe_token);
	T->token_quoted = FALSE;
	T->token_indirects_to_file = FALSE;
	T->token_indirects_to_hash = FALSE;

	string_position Q = P; /* the new token begins at position P, and ends just before Q */
	if ((first == '$') && (Str::get(Str::forward(P)) == '[')) @<Tokenise from a file@>
	else if ((first == '$') && (Str::get(Str::forward(P)) == '{')) @<Tokenise from a hash@>
	else if (first == '`') @<Mark to retokenise at expansion time@>
	else if (first == DELIA_QUOTE_CHARACTER) @<Take this quoted segment as the token@>
	else if (first == SHELL_QUOTE_CHARACTER) @<Take this shell quoted segment as the token@>
	else @<Take this unquoted word as the token@>;

	T->token_text = Str::new();
	Str::substr(T->token_text, P, Q);
	TEMPORARY_TEXT(tail)
	if (T->token_indirects_to_file) Q = Str::forward(Str::forward(Q));
	if (T->token_indirects_to_hash) Q = Str::forward(Str::forward(Q));
	Str::copy_tail(tail, txt, Str::index(Q));
	
	ADD_TO_LINKED_LIST(T, recipe_token, L);
	Delia::tokenise(L, tail);
	DISCARD_TEXT(tail)
}

@ A token written |$[filename$]| is expanded into the contents of that file.

@<Tokenise from a file@> =
	P = Str::forward(Str::forward(P));
	Q = P;
	while ((Str::in_range(Q)) &&
		!((Str::get(Q) == '$') && (Str::get(Str::forward(Q)) == ']')))
			Q = Str::forward(Q);
	T->token_indirects_to_file = TRUE;

@ More concisely, |${filename$}| expands to the MD5 hash of that file.

@<Tokenise from a hash@> =
	P = Str::forward(Str::forward(P));
	Q = P;
	while ((Str::in_range(Q)) &&
		!((Str::get(Q) == '$') && (Str::get(Str::forward(Q)) == '}')))
			Q = Str::forward(Q);
	T->token_indirects_to_hash = TRUE;

@ A token backticked, like |`this|, is retokenised before being expanded,
and then each individual resulting token is expanded.

@<Mark to retokenise at expansion time@> =
	T->token_quoted = NOT_APPLICABLE;
	P = Str::forward(P); Q = P;
	while ((Str::in_range(Q)) &&
		(!Characters::is_space_or_tab(Str::get(Q)))) Q = Str::forward(Q);

@ A token in quotes can include spaces, |'like so'|.

@<Take this quoted segment as the token@> =
	T->token_quoted = TRUE;
	int esc = FALSE;
	Q = Str::forward(Q);
	while ((Str::in_range(Q)) &&
		((esc) || (Str::get(Q) != DELIA_QUOTE_CHARACTER))) {
		if (Str::get(Q) == '\\') esc = TRUE; else esc = FALSE;
		Q = Str::forward(Q);
	}
	if (Str::get(Q) == DELIA_QUOTE_CHARACTER)
		Q = Str::forward(Q);

@<Take this shell quoted segment as the token@> =
	T->token_quoted = TRUE;
	int esc = FALSE;
	Q = Str::forward(Q);
	while ((Str::in_range(Q)) &&
		((esc) || (Str::get(Q) != SHELL_QUOTE_CHARACTER))) {
		if (Str::get(Q) == '\\') esc = TRUE; else esc = FALSE;
		Q = Str::forward(Q);
	}
	if (Str::get(Q) == SHELL_QUOTE_CHARACTER)
		Q = Str::forward(Q);

@ And otherwise any bare word is a token.

@<Take this unquoted word as the token@> =
	while ((Str::in_range(Q)) &&
		(!Characters::is_space_or_tab(Str::get(Q)))) Q = Str::forward(Q);

@ One further convenience:

=
void Delia::dequote_first_token(OUTPUT_STREAM, recipe_line *RL) {
	Str::clear(OUT);
	recipe_token *first = FIRST_IN_LINKED_LIST(recipe_token, RL->recipe_tokens);
	if (first) {
		text_stream *T = first->token_text;
		int L = Str::len(T);
		if (first->token_quoted == TRUE) {
			for (int i=1; i<L-1; i++)
				PUT(Str::get_at(T, i));
		} else {
			for (int i=0; i<L; i++)
				PUT(Str::get_at(T, i));
		}
	}
}
