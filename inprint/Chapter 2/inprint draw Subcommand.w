[InprintDraw::] inprint draw Subcommand.

The inprint draw subcommand draws a blueprint from a file tree.

@ The command line interface and help text:

@e DRAW_CLSUB
@e TO_CLSW
@e WRAPPER_CLSW

=
void InprintDraw::cli(void) {
	CommandLine::begin_subcommand(DRAW_CLSUB, U"draw");
	CommandLine::declare_heading(
		U"Usage: inprint draw DIRECTORY [-to FILE]\n\n"
		U"Draws a blueprint of the contents of the given DIRECTORY and writes this to\n"
		U"standard output, or else to FILE if '-to' is specified.");

	CommandLine::declare_switch(TO_CLSW, U"to", 2,
		U"name of blueprint file to write");
	CommandLine::declare_boolean_switch(WRAPPER_CLSW, U"including-wrapper", 1,
		U"including the directory itself as well as its contents", FALSE);

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inprint_draw_settings {
	struct filename *to;
	int wrapper;
} inprint_draw_settings;

void InprintDraw::initialise(inprint_draw_settings *ds) {
	ds->to = NULL;
	ds->wrapper = FALSE;
}

int InprintDraw::switch(inprint_instructions *ins, int id, int val, text_stream *arg) {
	inprint_draw_settings *ds = &(ins->draw_settings);
	switch (id) {
		case TO_CLSW:
			if (Str::eq(arg, I"-")) ds->to = NULL;
			else ds->to = Filenames::from_text(arg);
			return TRUE;
		case WRAPPER_CLSW:
			ds->wrapper = val;
			return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InprintDraw::run(inprint_instructions *ins) {
	inprint_draw_settings *ds = &(ins->draw_settings);
	if (ins->temp_file_setting)
		Errors::fatal_with_file("this is a file, not a directory", ins->temp_file_setting);
	if (ins->temp_path_setting == NULL)
		Errors::fatal("no directory given");
	text_stream *TO = STDOUT;
	struct text_stream TO_struct;
	if (ds->to) {
		TO = &TO_struct;
		if (STREAM_OPEN_TO_FILE(TO, ds->to, UTF8_ENC) == FALSE)
			Errors::fatal_with_file("unable to write blueprint", ds->to);
	}
	WRITE_TO(TO, "begin\n");
	pathname *home = ins->temp_path_setting;
	if (ds->wrapper) {
		WRITE_TO(TO, "directory: %S\n", Pathnames::directory_name(home));
		home = Pathnames::up(home);
	}
	InprintDraw::draw(TO, home, ins->temp_path_setting);
	WRITE_TO(TO, "end\n");
	if (ds->to) STREAM_CLOSE(TO);
}

void InprintDraw::draw(OUTPUT_STREAM, pathname *home, pathname *scan) {
	linked_list *L = Directories::listing(scan);
	text_stream *entry;
	LOOP_OVER_LINKED_LIST(entry, text_stream, L) {
		if (Platform::is_folder_separator(Str::get_last_char(entry))) {
			TEMPORARY_TEXT(subdir)
			WRITE_TO(subdir, "%S", entry);
			Str::delete_last_character(subdir);
			WRITE("directory: ");
			Pathnames::relative_URL(OUT, home, scan);
			WRITE("%S\n", subdir);
			DISCARD_TEXT(subdir)
			InprintDraw::draw(OUT, home, Pathnames::down(scan, subdir));
		} else {
			filename *F = Filenames::in(scan, entry);
			TEMPORARY_TEXT(extension)
			Filenames::write_extension(extension, F);
			int opaque = FALSE;
			if (Str::eq_insensitive(extension, I".css")) opaque = TRUE;
			if (Str::eq_insensitive(extension, I".js")) opaque = TRUE;
			if (Str::eq_insensitive(extension, I".gif")) opaque = TRUE;
			if (Str::eq_insensitive(extension, I".jpg")) opaque = TRUE;
			if (Str::eq_insensitive(extension, I".jpeg")) opaque = TRUE;
			if (Str::eq_insensitive(extension, I".png")) opaque = TRUE;
			DISCARD_TEXT(extension)
			if (opaque) WRITE("opaque ");
			WRITE("file");
			WRITE(": ");
			Pathnames::relative_URL(OUT, home, scan);
			WRITE("%S\n", entry);
			if (opaque == FALSE) {
				INDENT
				TEMPORARY_TEXT(contents)
				TextFiles::write_file_contents(contents, F);
				WRITE("%S", contents);
				DISCARD_TEXT(contents)
				OUTDENT
			}
		}
	}
}
