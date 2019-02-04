[Differ::] The Differ.

To provide text matching in the style of the Unix tool diff.

@ Our task is to take two strings, "ideal" and "actual", and return a
fairly minimal, fairly legible sequence of edits which would turn ideal
into actual. We won't use Myers's algorithm because it's overkill for the
text sizes we have here, and because we want to pay more attention to
word boundaries so as to produce human-readable results; the running
time below is worst-case quadratic in the number of words scanned, but
plenty fast enough for IF transcript use in practice.

We represent the series of edits as a linked list of |edit| structures,
and although these are not uniquely defined (the same comparison can
be represented in more than one way as a linked list of edits), we
do guarantee that the returned list will be empty if and only if the
ideal string has safely matched the actual one. As we'll see, this
is not quite as simple as saying that they hold the same text, because
some minor discrepancies are allowed.

Our main routine, then, will return (a pointer to) the following structure.

=
typedef struct diff_results {
	struct text_stream *ideal; /* record a copy of the question as well as the answer */
	struct text_stream *actual;
	struct linked_list *edits; /* of |edit| */
	MEMORY_MANAGEMENT
} diff_results;

@ Each edit consists of a nonempty chunk of text to be deleted, preserved
or inserted:

@d DELETE_EDIT -1
@d PRESERVE_EDIT 0
@d INSERT_EDIT 1

=
typedef struct edit {
	struct text_stream *fragment;
	int form_of_edit; /* one of the |*_EDIT| values */
	MEMORY_MANAGEMENT
} edit;

@h Edit lists.
We start with some boring routines to handle linked lists of edits in general.
First, creating a single new edit:

=
edit *Differ::new_edit(string_position from, string_position to, int form) {
	edit *E = CREATE(edit);
	E->fragment = Str::new();
	Str::substr(E->fragment, from, to);
	E->form_of_edit = form;
	return E;
}

@ Since we're not going to do any patching, the only thing we do with edit
lists is to print them out. The octal character values here represent ASCII
escape (27) followed by standard terminal emulation codes on Unix shells for
coloured text: deletions are in red, insertions in green.

=
int results_colouring = TRUE;
void Differ::set_colour_usage(int state) {
	results_colouring = state;
}

void Differ::print_edit_list(OUTPUT_STREAM, linked_list *L, text_stream *original) {
	if (L == NULL) WRITE("%S", original);
	else {
		edit *E;
		LOOP_OVER_LINKED_LIST(E, edit, L)
			switch (E->form_of_edit) {
				case DELETE_EDIT:
					if (results_colouring) WRITE("\033[31m");
					else WRITE("<deleted:");
					WRITE("%S", E->fragment);
					if (results_colouring) WRITE("\033[0m");
					else WRITE(">");
					break;
				case PRESERVE_EDIT:
					WRITE("%S", E->fragment);
					break;
				case INSERT_EDIT:
					if (results_colouring) WRITE("\033[32m");
					else WRITE("<inserted:");
					WRITE("%S", E->fragment);
					if (results_colouring) WRITE("\033[0m");
					else WRITE(">");
					break;
			}
	}
}

@ Now for basically the same thing in HTML, using CSS spans instead of terminal
colours:

=
void Differ::print_edit_list_as_HTML(OUTPUT_STREAM, linked_list *L, text_stream *original) {
	WRITE("<html>\n<body>\n<p class=\"node\">\n");
	if (L == NULL) Differ::print_fragment_as_HTML(OUT, original);
	else {
		edit *E;
		LOOP_OVER_LINKED_LIST(E, edit, L)
			switch (E->form_of_edit) {
				case DELETE_EDIT:
					WRITE("<span class=\"deletion\">");
					Differ::print_fragment_as_HTML(OUT, E->fragment);
					WRITE("</span>");
					break;
				case PRESERVE_EDIT:
					Differ::print_fragment_as_HTML(OUT, E->fragment);
					break;
				case INSERT_EDIT:
					WRITE("<span class=\"insertion\">");
					Differ::print_fragment_as_HTML(OUT, E->fragment);
					WRITE("</span>");
					break;
			}
	}
	WRITE("</p>\n</body>\n</html>\n");
}

void Differ::print_fragment_as_HTML(OUTPUT_STREAM, text_stream *original) {
	LOOP_THROUGH_TEXT(pos, original) {
		wchar_t c = Str::get(pos);
		switch (c) {
			case '<': WRITE("&lt;"); break;
			case '>': WRITE("&gt;"); break;
			case '&': WRITE("&amp;"); break;
			default: WRITE("%c", c); break;
		}
	}
}

@h The diff algorithm.
We do this in the simplest way possible. This outer routine, which is not
recursively called, sets up the returned structure and sends it back.

Note that a sequence of edits with no insertions or deletions means the
match was in fact perfect, and is converted to the null edit list.

=
diff_results *Differ::diff(text_stream *ideal, text_stream *actual) {
	diff_results *DR = CREATE(diff_results);
	DR->ideal = ideal;
	DR->actual = actual;

	LOGIF(DIFFER, "Differ:\nA = %S\nB = %S\n", ideal, actual);
	DR->edits = Differ::diff_outer(ideal, actual);

	edit *E;
	LOOP_OVER_LINKED_LIST(E, edit, DR->edits)
		if (E->form_of_edit != PRESERVE_EDIT)
			return DR;
	DR->edits = NEW_LINKED_LIST(edit);
	return DR;
}

@ The first level down simply starts the recursion, though it checks for
version lines first.

=
linked_list *Differ::diff_outer(text_stream *A, text_stream *B) {
	linked_list *edits = NEW_LINKED_LIST(edit);
	string_position A_from = Str::start(A);
	string_position A_to = Str::end(A);
	string_position B_from = Str::start(B);
	string_position B_to = Str::end(B);

	@<If both texts contain the Inform banner version line, diff around that@>;

	Differ::diff_inner(edits, A_from, A_to, B_from, B_to);
	return edits;
}

@ Any correctly formed I7 banner matches any other; this ensures that
transcripts of the same interaction, taken from builds on different days or
with different compiler versions, continue to match.

If text A (as we call the ideal version) and text B (the actual) both contain
I7 banners, we split them into before, then the banner, then after. The result
then consists of a diff of the before-texts, followed by preserving the actual
banner, followed by a diff of the after-texts.

@<If both texts contain the Inform banner version line, diff around that@> =
	match_results mr = Regexp::create_mr();
	wchar_t *template = L"(%c*?)(Release %d+ / Serial number %d+ / "
		"Inform 7 build %c%c%c%c %cI6%c+?lib %c+?SD)%c*";
	if (Regexp::match(&mr, A, template)) {
		string_position A_ver = Str::plus(A_from, Str::len(mr.exp[0])); /* at the R in "Release" */
		string_position A_post = Str::plus(A_ver, Str::len(mr.exp[1])); /* after version line ends */

		if (Regexp::match(&mr, B, template)) {
			string_position B_ver = Str::plus(B_from, Str::len(mr.exp[0]));
			string_position B_post = Str::plus(B_ver, Str::len(mr.exp[1]));

			Differ::diff_inner(edits, A_from, A_ver, B_from, B_ver);
			edit *E = Differ::new_edit(A_ver, A_post, PRESERVE_EDIT);
			ADD_TO_LINKED_LIST(E, edit, edits);
			Differ::diff_inner(edits, A_post, A_to, B_post, B_to);
			Regexp::dispose_of(&mr);
			return edits;
		}
		Regexp::dispose_of(&mr);
	}

@ The second level is at last recursive.

=
void Differ::diff_inner(linked_list *edits,
	string_position A_from, string_position A_to,
	string_position B_from, string_position B_to) {
	int A_len = Str::width_between(A_from, A_to);
	int B_len = Str::width_between(B_from, B_to);
	if ((A_len == 0) && (B_len == 0)) return;
	if (A_len < 0) internal_error("A text negative");
	if (B_len < 0) internal_error("B text negative");
	LOGIF(DIFFER, "Differ (recursion):\nA (%d chars) = ", A_len);
	if (Log::aspect_switched_on(DIFFER_DA)) Str::substr(DL, A_from, A_to);
	LOGIF(DIFFER, "\nB (%d chars) = ", B_len);
	if (Log::aspect_switched_on(DIFFER_DA)) Str::substr(DL, B_from, B_to);
	LOGIF(DIFFER, "\n");
	@<If A is empty B must be inserted, if B is empty A must be deleted@>;
	@<Any common prefix can be preserved@>;
	@<Any common suffix can be preserved@>;
	@<Splice around the longest common substring@>;
	@<If all else fails we can always just delete A and insert B@>;
}

@<If A is empty B must be inserted, if B is empty A must be deleted@> =
	if (A_len == 0) {
		edit *E = Differ::new_edit(B_from, B_to, INSERT_EDIT);
		ADD_TO_LINKED_LIST(E, edit, edits);
		return;
	}
	if (B_len == 0) {
		edit *E = Differ::new_edit(A_from, A_to, DELETE_EDIT);
		ADD_TO_LINKED_LIST(E, edit, edits);
		return;
	}

@ We look for the longest common prefix consisting of a sequence of entire
words, or at any rate, ending at a word boundary (in both texts).

@<Any common prefix can be preserved@> =
	string_position A_after_prefix = A_from;
	string_position B_after_prefix = B_from;
	for (; (Str::index(A_after_prefix) < Str::index(A_to)) &&
			(Str::index(B_after_prefix) < Str::index(B_to));
		A_after_prefix = Str::forward(A_after_prefix),
		B_after_prefix = Str::forward(B_after_prefix))
		if (Str::get(A_after_prefix) != Str::get(B_after_prefix))
			break;
	LOGIF(DIFFER, "Common prefix size %d\n", Str::width_between(A_from, A_after_prefix));

	/* roll backwards until we're at a word boundary between the prefix and the rest */
	while ((Str::width_between(A_from, A_after_prefix) > 0) &&
		(!Differ::boundary(Str::get(Str::back(A_after_prefix)), Str::get(A_after_prefix)))) {
		A_after_prefix = Str::back(A_after_prefix);
		B_after_prefix = Str::back(B_after_prefix);
	}
	LOGIF(DIFFER, "After rollback, prefix size %d\n", Str::width_between(A_from, A_after_prefix));

	/* if there's anything left, mark it as common text and recurse to move past it */
	if (Str::width_between(A_from, A_after_prefix) > 0) {
		edit *E = Differ::new_edit(A_from, A_after_prefix, PRESERVE_EDIT);
		ADD_TO_LINKED_LIST(E, edit, edits);
		Differ::diff_inner(edits, A_after_prefix, A_to, B_after_prefix, B_to);
		return;
	}

@ Similarly, we're only interested in a common suffix going back to the start
of a whole word.

@<Any common suffix can be preserved@> =
	string_position A_suffix = A_to;
	string_position B_suffix = B_to;
	for (; (Str::index(A_suffix) > Str::index(A_from)) &&
		(Str::index(B_suffix) > Str::index(B_from));
		A_suffix = Str::back(A_suffix),
		B_suffix = Str::back(B_suffix))
		if (Str::get(Str::back(A_suffix)) != Str::get(Str::back(B_suffix)))
			break;

	/* roll forwards until we're at a word boundary between the front and the suffix */
	while ((Str::width_between(A_suffix, A_to) > 0) &&
		(!Differ::boundary(Str::get(Str::back(A_suffix)), Str::get(A_suffix)))) {
		A_suffix = Str::forward(A_suffix);
		B_suffix = Str::forward(B_suffix);
	}

	/* if there's anything left, mark it as common text and recurse to move back past it */
	if (Str::width_between(A_suffix, A_to) > 0) {
		Differ::diff_inner(edits, A_from, A_suffix, B_from, B_suffix);
		edit *E = Differ::new_edit(A_suffix, A_to, PRESERVE_EDIT);
		ADD_TO_LINKED_LIST(E, edit, edits);
		return;
	}

@ In the typical use case most of the strings will now be gone, and this is
where the algorithm goes quadratic. We're going to look for the longest
common substring between A and B, provided it occurs at word boundaries,
and is not trivially short. If we find this, we'll recurse to diff the
text before the substring, then preserve the substring, then recurse to
diff the text afterwards.

@d MINIMUM_SPLICE_WORTH_BOTHERING_WITH 5

@d SPCHAR(A, n) Str::get(Str::plus(A##_from, n))

@<Splice around the longest common substring@> =
	int max_i = -1, max_j = -1, max_len = 0;
	for (int i = 0; i < A_len; i++)
		if ((i == 0) || (Differ::boundary(SPCHAR(A, i-1), SPCHAR(A, i))))
			for (int j = 0; j < B_len; j++)
				if ((j == 0) || (Differ::boundary(SPCHAR(B, j-1), SPCHAR(B, j)))) {
					int k;
					for (k = 0; (i+k < A_len) && (j+k < B_len) && (SPCHAR(A, i+k) == SPCHAR(B, j+k)); k++) ;
					while ((k > MINIMUM_SPLICE_WORTH_BOTHERING_WITH) &&
						(!(Differ::boundary(SPCHAR(A, i+k-1), SPCHAR(A, i+k))))) k--;
					if (k > max_len) {
						max_len = k; max_i = i; max_j = j;
					}
				}

	if (max_len >= MINIMUM_SPLICE_WORTH_BOTHERING_WITH) {
		LOGIF(DIFFER, "substring: ");
		for (int c=0; c<max_len; c++) {
			LOGIF(DIFFER, "%c", SPCHAR(A, max_i+c));
			if (SPCHAR(A, max_i+c) != SPCHAR(B, max_j+c)) internal_error("oops");
		}
		LOGIF(DIFFER, "\n---\n");

		string_position A_splice = Str::plus(A_from, max_i);
		string_position B_splice = Str::plus(B_from, max_j);
		string_position A_post = Str::plus(A_splice, max_len);
		string_position B_post = Str::plus(B_splice, max_len);

		Differ::diff_inner(edits, A_from, A_splice, B_from, B_splice);
		edit *E = Differ::new_edit(A_splice, A_post, PRESERVE_EDIT);
		ADD_TO_LINKED_LIST(E, edit, edits);
		Differ::diff_inner(edits, A_post, A_to, B_post, B_to);
		if (Log::aspect_switched_on(DIFFER_DA)) Differ::print_edit_list(DL, edits, NULL);
		LOGIF(DIFFER, "\n---\n");
		return;
	}

@ If we can't find any good substring, all we can usefully do is say that
the text has entirely changed, and we display this as cleanly as possible:

@<If all else fails we can always just delete A and insert B@> =
	edit *E = Differ::new_edit(A_from, A_to, DELETE_EDIT);
	ADD_TO_LINKED_LIST(E, edit, edits);
	E = Differ::new_edit(B_from, B_to, INSERT_EDIT);
	ADD_TO_LINKED_LIST(E, edit, edits);
	return;

@ This was the definition of "word boundary" used, where these are expected
to be adjacent characters (in either direction). For best results, we want
a version of |isalpha| which respects Unicode, or else the above algorithm
will sometimes show edits mid-word at accented letters.

=
int Differ::boundary(int c, int d) {
	if ((Characters::isalpha(c)) && (Characters::isalpha(d))) return FALSE;
	return TRUE;
}

@h Printing results.
That's all except to provide some routines for printing out what we found:

=
void Differ::print_results(OUTPUT_STREAM, diff_results *DR, text_stream *original) {
	Differ::print_edit_list(OUT, DR->edits, original);
}

void Differ::print_results_as_HTML(OUTPUT_STREAM, diff_results *DR, text_stream *original) {
	Differ::print_edit_list_as_HTML(OUT, DR->edits, original);
}
