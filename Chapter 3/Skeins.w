[Skeins::] Skeins.

To build and compare skein threads.

@h About skeins.
"Skein" is a term coined by the Inform project for a tree of possible
textual commands and responses. Branching in the tree represents a choice
of which command to give. Such branches are useful when considering what
lines of play are possible, but Intest is only interested in the past, not
the future, and there is only one linear past. So Intest will only consider
skeins which are not so much trees as trunks: a skein for us is going to be
a linked list where each node is a |skein| structure, not a tree of them.

All this may seem as if it applies only to testing interactive fiction
projects created by Inform, and certainly the full power of the code below is
only really useful to implement the Delia commands |match glulxe transcript|
and |match frotz transcript|. But it is actually used for every sort of match.
When Intest needs to match two plain text files, it creates skeins for them
with one node per line of text. It follows that virtually all Intest runs do
use the code below, even if only minimally.

Skein text can be supplied in a variety of formats:

@e I7_OUTPUT_SKF from 1 /* I7 only: console output of I7 compiler problem messages */
@e I6_OUTPUT_SKF /* I6 only: console output of I6 compiler problem messages */
@e GENERIC_SKF /* I7 only: a transcript which might be either from Frotz or Glulxe */
@e DUMB_FROTZ_SKF /* I7 only: a transcript file produced by dumb-frotz */
@e DUMB_GLULXE_SKF /* I7 only: a transcript file produced by dumb-glulxe */
@e I7_SKEIN_SKF /* I7 only: from the XML-format Skein file of an I7 project bundle */
@e PLAIN_SKF /* for plain text matching, nothing to do with I7 */

=
typedef struct skein {
	int from_format; /* one of the |*_SKF| constants above */
	struct text_stream *text; /* the real content, the text of what happened */
	struct text_stream *label;
	int line_count_label;
	int disposed_of;
	struct skein *down; /* thus making this a linked list of |skein| */
	CLASS_DEFINITION
} skein;

@ =
void Skeins::write(OUTPUT_STREAM, skein *sk) {
	int count = 1;
	while (sk) {
		WRITE("Node %d: ", count++);
		WRITE("%S", sk->text);
		sk = sk->down;
	}
}

void Skeins::write_node_label(OUTPUT_STREAM, char *format, void *vS) {
	skein *A = (skein *) vS;
	if (A == NULL) WRITE("<null-node>");
	else if (A->line_count_label >= 0) WRITE("line %d", A->line_count_label);
	else WRITE("%S", A->label);
}

@h Stringing skeins together.
The Tester, when trying to match two files |A| and |B|, calls one of the
following on each to turn it into a skein.

=
skein *Skeins::from_i7_problems(filename *F, int cle) {
	return Skeins::read(F, I7_OUTPUT_SKF, cle, NULL, FALSE);
}
skein *Skeins::from_i6_console_output(filename *F) {
	return Skeins::read(F, I6_OUTPUT_SKF, FALSE, NULL, FALSE);
}
skein *Skeins::from_transcript(filename *F, int cle) {
	return Skeins::read(F, GENERIC_SKF, cle, NULL, FALSE);
}
skein *Skeins::from_Z_transcript(filename *F, int cle) {
	return Skeins::read(F, DUMB_FROTZ_SKF, cle, NULL, FALSE);
}
skein *Skeins::from_G_transcript(filename *F, int cle) {
	return Skeins::read(F, DUMB_GLULXE_SKF, cle, NULL, FALSE);
}
skein *Skeins::from_I7_skein(filename *F, text_stream *seek, int actual_flag) {
	return Skeins::read(F, I7_SKEIN_SKF, FALSE, seek, actual_flag);
}
skein *Skeins::from_plain_text(filename *F) {
	return Skeins::read(F, PLAIN_SKF, FALSE, NULL, FALSE);
}

@ All of which use the following:

=
skein *Skeins::read(filename *F, int format, int cle, text_stream *seek, int actual_flag) {
	TEMPORARY_TEXT(TB)
	TEMPORARY_TEXT(CN)
	TEMPORARY_TEXT(NL)
	skein_state sks;
	@<Initialise the Skein reader state@>;
	TextFiles::read(F, FALSE, "can't open problems transcript", TRUE,
		&Skeins::read_assistant, NULL, &sks);
	if (sks.writing_to) Skeins::flush(&sks);
	DISCARD_TEXT(CN)
	DISCARD_TEXT(NL)
	DISCARD_TEXT(TB)
	return sks.root;
}

@ =
typedef struct skein_state {
	struct skein *root;
	struct skein *tendril;
	struct skein *writing_to;
	int detected_format;
	struct text_stream *turn_buffer;
	int double_starred;
	struct text_stream *node_to_seek;
	struct text_stream *current_node;
	struct text_stream *next_label;
	int actual_flag;
} skein_state;

@<Initialise the Skein reader state@> =
	sks.root = NULL;
	sks.tendril = NULL;
	sks.writing_to = NULL;
	sks.detected_format = format;
	sks.turn_buffer = TB;
	sks.double_starred = cle;
	sks.node_to_seek = seek;
	sks.current_node = CN;
	sks.next_label = NL;
	sks.actual_flag = actual_flag;

@ The following, then, is called line by line on the skein file being read,
with the above state being maintained.

=
void Skeins::read_assistant(text_stream *line_text, text_file_position *tfp, void *vsks) {
	if (line_text == NULL) internal_error("null line");
	skein_state *sks = vsks;

	@<Autodetect the interpreter which produced this generic transcript@>;
	@<Skip the first line of a Frotz transcript@>;

	switch (sks->detected_format) {
		case PLAIN_SKF: @<Read from plain text@>; break;
		case I7_SKEIN_SKF: @<Read from XML@>; break;
		case I7_OUTPUT_SKF: @<Read from Inform 7 console output@>; break;
		case I6_OUTPUT_SKF: @<Read from Inform 6 console output@>; break;
		case DUMB_FROTZ_SKF: @<Read from a Frotz transcript@>; break;
		case DUMB_GLULXE_SKF: @<Read from a Glulxe transcript@>; break;
	}

	if (sks->writing_to) @<Transcribe this line into the turn buffer@>;
}

@ Dumb-frotz indents everything by two spaces; dumb-glulxe does not. This
can be used to tell which one produced a given transcript file.

@<Autodetect the interpreter which produced this generic transcript@> =
	if ((sks->detected_format == GENERIC_SKF) && (Str::len(line_text) > 0)) {
		if ((Str::get_at(line_text, 0) == ' ') && (Str::get_at(line_text, 1) == ' '))
			sks->detected_format = DUMB_FROTZ_SKF;
		else
			sks->detected_format = DUMB_GLULXE_SKF;
	}

@ The opening line of a dumb-frotz transcript is a plain text form of the 
status line early in play. We don't want that.

@<Skip the first line of a Frotz transcript@> =
	if ((tfp->line_count == 0) && (sks->detected_format == DUMB_FROTZ_SKF))
		return;

@ See the documentation for why we forgive differences in thread number.

@<Read from plain text@> =
	Skeins::new_node(sks, tfp->line_count+1, NULL, sks->detected_format);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, line_text, U"(%c*?)[/\\]T%d+[/\\](%c*)")) {
		Str::clear(line_text);
		WRITE_TO(line_text, "Txx/%S", mr.exp[1]);
	}

@ Let us not pretend that this is a properly capable XML reader: it's
nothing of the kind, and simply does just enough to scrape the necessary
text out of a Skein file in an I7 project. This is not the place to
document that format.

@<Read from XML@> =
	int L = Str::len(line_text);
	@<Nefariously force a line break before any tag opener@>;
	@<Nefariously make a short tag its own line@>;

	match_results mr = Regexp::create_mr();
	@<Extract the node ID, if this line declares one@>;
	if (Str::eq(line_text, I"</item>")) Str::clear(sks->current_node);

	if ((Str::len(sks->node_to_seek) == 0) ||
		(Str::eq(sks->node_to_seek, sks->current_node)))
		@<We want this node@>;
	Regexp::dispose_of(&mr);

@ Given the line |hello, <it>you|, split into two lines |hello, | and
|<it>you|, by calling this line-reading routine again on each. (That's
what's nefarious.)

@<Nefariously force a line break before any tag opener@> =
	for (int i = 0; i < L; i++) {
		if ((i > 0) && (Str::get_at(line_text, i) == '<')) {
			TEMPORARY_TEXT(front)
			TEMPORARY_TEXT(back)
			Str::copy(front, line_text);
			Str::truncate(front, i);
			Skeins::read_assistant(front, tfp, vsks);
			Str::copy_tail(back, line_text, i);
			Skeins::read_assistant(back, tfp, vsks);
			DISCARD_TEXT(front)
			DISCARD_TEXT(back)
			return;
		}
	}

@ If we're here, the only place a |<| can be is at the start of a line.
If we can also see a matching |>| then again split, so that |<it>you|
would split into two lines |<it>| and |you|.

@<Nefariously make a short tag its own line@> =
	if (Str::get_first_char(line_text) == '<') {
		for (int i = 0; i < L; i++) {
			if ((i > 0) && (i < L-1) && (Str::get_at(line_text, i) == '>')) {
				TEMPORARY_TEXT(front)
				TEMPORARY_TEXT(back)
				Str::copy(front, line_text);
				Str::truncate(front, i+1);
				Skeins::read_assistant(front, tfp, vsks);
				Str::copy_tail(back, line_text, i+1);
				Skeins::read_assistant(back, tfp, vsks);
				DISCARD_TEXT(front)
				DISCARD_TEXT(back)
				return;
			}
		}
	}

@ So now a line is either an entire tag, or entirely not a tag. In a Skein
file, |<item nodeId="...">| is what declares a node ID, and it's now easy
to match for that:

@<Extract the node ID, if this line declares one@> =
	if (Regexp::match(&mr, line_text, U"<item nodeId=\"(%c*)\">"))
		Str::copy(sks->current_node, mr.exp[0]);

@ Sometimes the I7 app wants us to make a skein from the whole file, and
sometimes just from a single node in it. Either way, this is run when
we are at a node whose contents we care about:

@<We want this node@> =
	if (Regexp::match(&mr, line_text, U"<command %c*>"))
		Str::put_at(sks->next_label, 0, 1);
	if ((Regexp::match(&mr, line_text, U"<result %c*>")) && (sks->actual_flag)) {
		Skeins::new_node(sks, -1, sks->next_label, sks->detected_format);
		return;
	}
	if ((Regexp::match(&mr, line_text, U"<commentary %c*>")) && (sks->actual_flag == FALSE)) {
		Skeins::new_node(sks, -1, sks->next_label, sks->detected_format);
		return;
	}
	if ((Regexp::match(&mr, line_text, U"</result%c*>")) ||
		(Regexp::match(&mr, line_text, U"</commentary%c*>"))) {
		if (sks->writing_to) Skeins::flush(sks);
		sks->writing_to = NULL;
		return;
	}
	if (Str::get_first_char(line_text) != '<') {
		if (Str::get_at(sks->next_label, 0) == 1) {
			Str::clear(sks->next_label);
			Skeins::remove_XML_escapes(sks->next_label, line_text);
		}
	}

@ This code is used only for matching problem message output from the I7
compiler. We ignore |Offending filename| lines for much the reason above --
they exist only in fatal file-system problem messages in any case. A line
in the form
= (text)
	Problem__ PM_ActivityVariableNameless
=
is printed by I7 only on test runs, and lets us check that the right
problem message is being produced. We don't ignore such a line: we capture
the problem name and label the Skein node with it.

@<Read from Inform 7 console output@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U"Inform 7 has finished%c*")) {
		if (sks->writing_to) Skeins::flush(sks);
		sks->writing_to = NULL;
		Regexp::dispose_of(&mr);
		return;
	}
	if (Regexp::match(&mr, line_text, U"%c*Offending filename%c*")) return;
	if (Regexp::match(&mr, line_text, U"Problem__ (%c*)")) {
		Skeins::new_node(sks, -1, mr.exp[0], sks->detected_format);
		Regexp::dispose_of(&mr);
		return;
	}
	Regexp::dispose_of(&mr);

@<Read from Inform 6 console output@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U"Inform %C%C%C%C (%C+ %C+ %C%C%C%C)")) {
		if (sks->writing_to) Skeins::flush(sks);
		sks->writing_to = NULL;
		Regexp::dispose_of(&mr);
		return;
	}
	if (Regexp::match(&mr, line_text, U"(%c*) %(%C+ seconds%) *")) {
		Str::clear(line_text);
		WRITE_TO(line_text, "%S", mr.exp[0]);
	}
	Regexp::dispose_of(&mr);

@<Read from a Frotz transcript@> =
	inchar32_t la[6];
	Str::copy_to_wide_string(la, line_text, 6);
	if ((tfp->line_count == 1) && (la[0] == 0)) return;
	if ((tfp->line_count == 2) && (la[0] == 'E') &&
		(la[1] == 'O') && (la[2] == 'T') && (la[3] == 0)) return;

	if (sks->writing_to == NULL)
		Skeins::new_node(sks, -1,
			Str::new_from_ISO_string("opening text"), sks->detected_format);

	if (la[0] == '>') return;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U" %[quitting the game%]%c*")) {
		Regexp::dispose_of(&mr);
		return;
	}

	if ((la[0] == ' ') && (la[1] == ' ') && (la[2] == '>') && (la[3] == '[')) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line_text, U"%c%c%c%c%d+%] (%c+)")) {
			TEMPORARY_TEXT(label)
			WRITE_TO(label, "reply to \"%S\"", mr.exp[0]);
			Skeins::new_node(sks, -1, label, sks->detected_format);
			DISCARD_TEXT(label)
			Regexp::dispose_of(&mr);
			return;
		}
	}
	if ((la[0] == ' ') && (la[1] == ' ') && (la[2] == '*') &&
		(la[3] == '*') && (la[4] == ' ')) {
		TEMPORARY_TEXT(label)
		TEMPORARY_TEXT(tail)
		Str::copy_tail(tail, line_text, 5);
		WRITE_TO(label, "reply to \"%S\"", tail);
		Skeins::new_node(sks, -1, label, sks->detected_format);
		DISCARD_TEXT(label)
		DISCARD_TEXT(tail)
		return;
	}

@<Read from a Glulxe transcript@> =
	inchar32_t la[6];
	Str::copy_to_wide_string(la, line_text, 6);
	if (sks->writing_to == NULL)
		Skeins::new_node(sks, -1,
			Str::new_from_ISO_string("opening text"), sks->detected_format);

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U">Are you sure you want to quit?%c*")) {
		Regexp::dispose_of(&mr);
		return;
	}

	if (Regexp::match(&mr, line_text, U">%(Testing.%)%c*")) {
		Regexp::dispose_of(&mr);
		break;
	}

	if ((la[0] == '>') && (la[1] == '[') &&
		(Regexp::match(&mr, line_text, U"%c%c%d+%] (%c+)"))) {
		TEMPORARY_TEXT(label)
		WRITE_TO(label, "reply to \"%S\"", mr.exp[0]);
		Skeins::new_node(sks, -1, label, sks->detected_format);
		DISCARD_TEXT(label)
		return;
	}
	if ((sks->double_starred) &&
		(la[0] == '*') && (la[1] == '*') && (la[2] == ' ')) {
		TEMPORARY_TEXT(label)
		TEMPORARY_TEXT(tail)
		Str::copy_tail(tail, line_text, 3);
		WRITE_TO(label, "reply to \"%S\"", tail);
		Skeins::new_node(sks, -1, label, sks->detected_format);
		DISCARD_TEXT(label)
		DISCARD_TEXT(tail)
		return;
	}

@ We lose the redundant two-space indentation of a dumb-frotz transcript.
Otherwise, we simply add the new line to the current turn buffer.

@<Transcribe this line into the turn buffer@> =
	if (sks->detected_format == DUMB_FROTZ_SKF) {
		Str::delete_first_character(line_text);
		Str::delete_first_character(line_text);
	}

	if (sks->detected_format == I7_SKEIN_SKF)
		Skeins::remove_XML_escapes(sks->turn_buffer, line_text);
	else
		Str::concatenate(sks->turn_buffer, line_text);
	PUT_TO(sks->turn_buffer, '\n');

@ This "utility" simply removes the XML escapes for |<|, |>| and |&|.

=
void Skeins::remove_XML_escapes(OUTPUT_STREAM, text_stream *F) {
	int L = Str::len(F);
	for (int i = 0; i < L; i++) {
		inchar32_t la[6];
		Str::copy_to_wide_string(la, F, 6);

		if ((la[0] == '&') && (la[1] == 'l') && (la[2] == 't') && (la[3] == ';')) {
			PUT('<');
			i += 3;
		} else if ((la[0] == '&') && (la[1] == 'g') && (la[2] == 't') && (la[3] == ';')) {
			PUT('>');
			i += 3;
		} else if ((la[0] == '&') && (la[1] == 'a') && (la[2] == 'm') && (la[3] == 'p') && (la[4] == ';')) {
			PUT('&');
			i += 4;
		} else PUT(la[0]);
	}
}

@ The following begins a new node in the Skein:

=
void Skeins::new_node(skein_state *sks, int ln, text_stream *label, int format) {
	skein *new_node = CREATE(skein);
	new_node->label = NULL;
	new_node->line_count_label = ln;
	if (ln < 0) new_node->label = Str::duplicate(label);
	new_node->text = Str::new();
	new_node->down = NULL;
	new_node->from_format = format;
	if (sks->writing_to) Skeins::flush(sks);
	sks->writing_to = new_node;
	if (sks->root == NULL) sks->root = new_node;
	else sks->tendril->down = new_node;
	sks->tendril = new_node;
	new_node->disposed_of = FALSE;
}

@ While this routine brings the existing node -- that is, the one currently
being written to -- to an end:

=
void Skeins::flush(skein_state *sks) {
	if (sks->writing_to == NULL) return;
	sks->writing_to->text = Str::duplicate(sks->turn_buffer);
	Str::clear(sks->turn_buffer);
}

@h Disposing of skeins.
On a long run of many tests, Intest creates an enormous number of |skein|
structures, so this is the one data structure it takes the trouble to
deallocate when it's done with them. We need to do this depth-first, i.e.,
from the bottom upwards, because if you start at the top then you destroy
the link to the rest before you can get to them.

=
void Skeins::dispose_of(skein *S) {
	if (S)
		for (skein *N = S->down; S; S = N, N = (S)?(S->down):NULL) {
			if (S->disposed_of) internal_error("skein node doubly disposed of");
			S->disposed_of = TRUE;
			if (S->text) Str::dispose_of(S->text);
			if (S->label) Str::dispose_of(S->label);
			DESTROY(S, skein);
		}
}

@h Matching skeins.
So, this was what it was all about. Given two skeins, do they hold the same
sequence of pieces of text? And if not, find a clean way to express the
differences between them.

To match perfectly, the skeins |A| (actual) and |I| (ideal) must have the
same number of nodes, and each corresponding pair of nodes must have the
same "label" and the same "text".

@d MAX_COMPARE_ERRORS_REPORTED 10

=
int Skeins::compare(OUTPUT_STREAM, skein *A, skein *I, int problems,
	int allow_platform_variance) {
	int count = 1, error_count = 0;
	char *thing = "problem";
	if (problems == FALSE) { count = 0; thing = "turn"; }
	while (((A) || (I)) && (error_count < MAX_COMPARE_ERRORS_REPORTED)) {
		if ((A) && (I)) {
			@<Both skeins are still going@>;
			continue;
		}
		if (A) {
			@<The actual skein is still going, but the ideal one has run out@>;
			continue;
		}
		if (I) {
			@<The ideal skein is still going, but the actual one has run out@>;
			continue;
		}
	}
	if (error_count >= MAX_COMPARE_ERRORS_REPORTED)
		WRITE("...and so on (stopped reading after %d errors)\n", MAX_COMPARE_ERRORS_REPORTED);
	if (error_count > 0) return 1; else return 0;
}

@<Both skeins are still going@> =
	int same_label = FALSE;
	if ((A->line_count_label >= 0) && (A->line_count_label >= I->line_count_label))
		same_label = TRUE;
	if ((A->label) && (I->label) && (Str::eq(A->label, I->label))) same_label = TRUE;
	if (same_label) @<Both skeins have the same label at this node@>
	else @<The two skeins have different labels at this node@>;

@<Both skeins have the same label at this node@> =
	if (Str::ne(A->text, I->text)) {
		diff_results *DR = Differ::diff(I->text, A->text, allow_platform_variance);
		if (LinkedLists::len(DR->edits) > 0) {
			if (A->from_format == PLAIN_SKF)
				WRITE("Discrepancy at %k:\n", A);
			else
				WRITE("Discrepancy on %s %d (%k):\n", thing, count, A);
			INDENT;
			Differ::print_results(OUT, DR, A->text);
			OUTDENT;
			error_count++;
		}
	}
	count++;
	A = A->down;
	I = I->down;

@<The two skeins have different labels at this node@> =
	WRITE("Unexpected %s %d (%k not %k):\n%S", thing, count++, A, I, A->text); INDENT;
	OUTDENT;
	A = A->down;
	error_count++;

@<The actual skein is still going, but the ideal one has run out@> =
	if (A->from_format == PLAIN_SKF)
		WRITE("Extra %k:\n%S", A, A->text);
	else
		WRITE("Unexpected %s %d (%k):\n%S", thing, count++, A, A->text); INDENT;
	OUTDENT;
	A = A->down;
	error_count++;

@<The ideal skein is still going, but the actual one has run out@> =
	if (I->from_format == PLAIN_SKF)
		WRITE("Missing %k:\n%S", I, I->text);
	else
		WRITE("Missing %s (%k):\n%S", thing, I, I->text); INDENT;
	OUTDENT;
	I = I->down;
	error_count++;

@ This powers |-test-skein|, which specifies an exact node ID and wants to
compare only the text at that one node. We therefore make mimimal |skein|
structures -- each a singleton -- and then just call the Differ directly
to compare the two.

=
void Skeins::test_i7_skein(OUTPUT_STREAM, filename *F, text_stream *node_id) {
	skein *A = Skeins::from_I7_skein(F, node_id, TRUE);
	skein *I = Skeins::from_I7_skein(F, node_id, FALSE);
	diff_results *DR = Differ::diff(I->text, A->text, FALSE);
	Differ::print_results_as_HTML(OUT, DR, A->text);
}
