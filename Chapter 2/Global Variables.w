[Globals::] Global Variables.

To manage a set of text variables held in common among all test cases.

@ A global variable is (mostly) created in a recipe file by a command like:
= (text)
	-set hash_utility 'md5'
=
In Delia code it would then be referred to as |$$hash_utility|. This section
manages the global variables, but has nothing to do with Delia's local
variables, which have single-dollar names conventionally written in
capitals |$THUS|.

=
dictionary *globals_dictionary = NULL; /* until first variable is created */

@h Basic operations.
Variables are never destroyed, so we have just three basic operations: create,
get and set. Variables are identified by name:

=
linked_list *created_globals = NULL;
void Globals::create(text_stream *name) {
	LOGIF(VARIABLES, "global: created %S\n", name);
	if (globals_dictionary == NULL)
		globals_dictionary = Dictionaries::new(32, TRUE);
	if (Dictionaries::find(globals_dictionary, name) == NULL) {
		Dictionaries::create_text(globals_dictionary, name);
		if (created_globals == NULL)
			created_globals = NEW_LINKED_LIST(text_stream);
		ADD_TO_LINKED_LIST(name, text_stream, created_globals);
	}
}

linked_list *Globals::all(void) {
	if (created_globals == NULL)
		created_globals = NEW_LINKED_LIST(text_stream);
	return created_globals;
}

int Globals::exists(text_stream *name) {
	if (Str::len(name) == 0) return FALSE;
	TEMPORARY_TEXT(key)
	if ((Str::get_at(name, 0) == '$') && (Str::get_at(name, 1) == '$')) {
		Str::substr(key, Str::at(name, 2), Str::end(name));
	} else {
		Str::copy(key, name);
	}
	int found = FALSE;
	if (Dictionaries::find(globals_dictionary, key)) found = TRUE;
	DISCARD_TEXT(key)
	return found;
}

@ Get is easy:

=
text_stream *Globals::get(text_stream *name) {
	if (Str::len(name) == 0) return FALSE;
	return Dictionaries::get_text(globals_dictionary, name);
}

@ Set is more interesting because we perform expansions of any uses of the
notation |$$varname| into the current value of |varname| en route.

=
void Globals::set(text_stream *name, text_stream *original) {
	TEMPORARY_TEXT(value)
	Str::copy(value, original);
	@<Make substitutions@>;
	LOGIF(VARIABLES, "var: %S <-- <%S>\n", name, value);
	if (Dictionaries::find(globals_dictionary, name) == NULL)
		internal_error("can't find dictionary entry to write to");
	Str::copy(Dictionaries::get_text(globals_dictionary, name), value);
	DISCARD_TEXT(value)
}

@<Make substitutions@> =
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, value, U"(%c*)$$(%i+)(%c*)")) {
		Str::copy(value, mr.exp[0]);
		if (Dictionaries::find(globals_dictionary, mr.exp[1])) {
			WRITE_TO(value, "%S", Globals::get(mr.exp[1]));
		} else {
			Errors::with_text("no such setting as $$%S", mr.exp[1]);
			WRITE_TO(value, "(novalue)");
		}
		WRITE_TO(value, "%S", mr.exp[2]);
	}
	Regexp::dispose_of(&mr);

@h As filenames.
It turns out to be convenient to be able to read them as filenames, where
we interpret |/| as a file separator even on Windows, so that common settings
files can be used across all platforms.

=
pathname *Globals::to_pathname(text_stream *name) {
	text_stream *text = Globals::get(name);
	if (text == NULL) return NULL;
	TEMPORARY_TEXT(val)
	Str::copy(val, text);
	LOOP_THROUGH_TEXT(pos, val)
		if (Platform::is_folder_separator(Str::get(pos)))
			Str::put(pos, FOLDER_SEPARATOR);
	pathname *P = Pathnames::from_text(val);
	DISCARD_TEXT(val)
	return P;
}

@ =
filename *Globals::to_filename(text_stream *name) {
	text_stream *text = Globals::get(name);
	if (Str::len(text) == 0) return NULL;
	TEMPORARY_TEXT(val)
	Str::copy(val, text);
	LOOP_THROUGH_TEXT(pos, val)
		if (Platform::is_folder_separator(Str::get(pos)))
			Str::put(pos, FOLDER_SEPARATOR);
	filename *F = Filenames::from_text(val);
	DISCARD_TEXT(val)
	return F;
}

@h Initialisation.
When Intest starts up, it creates three variables to kick off with:

=
void Globals::create_platform(pathname *home) {
	Globals::create(I"platform");
	Globals::set(I"platform", Str::new_from_ISO_string(PLATFORM_STRING));
	TEMPORARY_TEXT(project_path)
	WRITE_TO(project_path, "%p", home);
	Globals::create(I"project");
	Globals::set(I"project", project_path);
	DISCARD_TEXT(project_path)
}

void Globals::create_internal(void) {
	Globals::create(I"internal");
	Globals::set(I"internal", I"inform7/Internal");
}

void Globals::create_workspace(void) {
	Globals::create(I"platform");
	Globals::set(I"platform", Str::new_from_ISO_string(PLATFORM_STRING));
	Globals::create(I"workspace");
	pathname *P = Pathnames::down(installation, I"Workspace");
	TEMPORARY_TEXT(PT)
	WRITE_TO(PT, "%p", P);
	Globals::set(I"workspace", PT);
	DISCARD_TEXT(PT)
}

text_stream *Globals::get_platform(void) {
	return Globals::get(I"platform");
}
