[InprintBuild::] inprint build Subcommand.

The inprint build subcommand builds a file tree from a blueprint.

@ The command line interface and help text:

@e BUILD_CLSUB
@e IN_CLSW
@e ARCHIVES_CLSW

=
void InprintBuild::cli(void) {
	CommandLine::begin_subcommand(BUILD_CLSUB, U"build");
	CommandLine::declare_heading(
		U"Usage: inprint build FILE [-in DIRECTORY]\n\n"
		U"Builds a file tree from the blueprint in FILE in the current working directory, "
		U"or else inside DIRECTORY if '-in' is specified.");

	CommandLine::declare_switch(IN_CLSW, U"in", 2,
		U"directory in which to build file tree");
	CommandLine::declare_switch(ARCHIVES_CLSW, U"archives", 2,
		U"directory in which to find blueprint");

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inprint_build_settings {
	struct pathname *in;
	struct pathname *archives;
} inprint_build_settings;

void InprintBuild::initialise(inprint_build_settings *bs) {
	bs->in = NULL;
	bs->archives = NULL;
}

int InprintBuild::switch(inprint_instructions *ins, int id, int val, text_stream *arg) {
	inprint_build_settings *bs = &(ins->build_settings);
	switch (id) {
		case IN_CLSW: bs->in = Pathnames::from_text(arg); return TRUE;
		case ARCHIVES_CLSW: bs->archives = Pathnames::from_text(arg); return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InprintBuild::run(inprint_instructions *ins) {
	inprint_build_settings *bs = &(ins->build_settings);
	if (ins->temp_path_setting)
		Errors::fatal_with_path("this is a directory, not a blueprint file", ins->temp_path_setting);
	if (ins->temp_file_setting == NULL)
		Errors::fatal("no blueprint file given");
	if (bs->archives) {
		ins->temp_file_setting = Filenames::in(bs->archives, Filenames::get_leafname(ins->temp_file_setting));
	}
	build_reader br;
	br.report = STDOUT;
	if (silent_mode) br.report = NULL;
	br.file_being_written = NULL;
	br.lines_written = 0;
	br.begin_found = FALSE; br.end_found = FALSE;
	br.lc = 0;
	br.to = bs->in;
	TextFiles::read(ins->temp_file_setting, TRUE, "unable to open blueprint", TRUE,
		InprintBuild::reader, NULL, (void *) &br);
	if (br.file_being_written)
		Errors::at_position("ended in mid-file", ins->temp_file_setting, br.lc);
	else if (br.end_found == FALSE)
		Errors::at_position("ended without 'end'", ins->temp_file_setting, br.lc);
}

typedef struct build_reader {
	int begin_found;
	int end_found;
	struct text_stream *report;
	struct filename *file_being_written;
	int lines_written;
	struct text_stream file_out;
	int lc;
	struct pathname *to;
} build_reader;

void InprintBuild::reader(text_stream *line, text_file_position *tfp, void *void_br) {
	build_reader *br = (build_reader *) void_br;
	text_stream *OUT = br->report;
	br->lc++;
	int from = -1;
	if (Str::get_at(line, 0) == '\t') from = 1;
	else if (Str::begins_with(line, I"    ")) from = 4;
	else if ((Str::is_whitespace(line)) && (br->file_being_written)) from = 0;
	if (from >= 0) {
		if (br->file_being_written) {
			if (br->lines_written > 0) PUT_TO(&(br->file_out), '\n');
			for (int i=from; i<Str::len(line); i++)
				PUT_TO(&(br->file_out), Str::get_at(line, i));
			br->lines_written++;
		} else {
			Errors::in_text_file("file content occurs outside of file", tfp);
			return;
		}
	} else {
		if (br->file_being_written) {
			STREAM_CLOSE(&(br->file_out));
			WRITE("%d line(s) written to %f\n", br->lines_written, br->file_being_written);
			br->file_being_written = NULL;
			br->lines_written = 0;
		}
		Str::trim_all_white_space_at_end(line);
		if (br->end_found) {
			if (Str::len(line) == 0) return;
			Errors::in_text_file("material after end", tfp);
			return;
		}
		if (Str::eq(line, I"begin")) {
			if (br->begin_found) {
				Errors::in_text_file("begin occurs twice", tfp);
				return;
			}
			br->begin_found = TRUE;
			return;
		}
		if (Str::eq(line, I"end")) {
			if (br->end_found) {
				Errors::in_text_file("end occurs twice", tfp);
				return;
			}
			br->end_found = TRUE;
			return;
		}
		if (br->begin_found == FALSE) {
			Errors::in_text_file("material without begin", tfp);
			return;
		}
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"directory: *(%c+)")) {
			pathname *P = Pathnames::from_text_relative(br->to, mr.exp[0]);
			if (Pathnames::create_in_file_system(P))
				WRITE("created directory %p\n", P);
			else
				Errors::fatal_with_path("unable to create directory", P);
		} else if (Regexp::match(&mr, line, U"opaque file: *(%c+)")) {
			filename *F = Filenames::from_text_relative(br->to, mr.exp[0]);
			text_stream *TO = &(br->file_out);
			if (STREAM_OPEN_TO_FILE(TO, F, UTF8_ENC) == FALSE)
				Errors::fatal_with_file("unable to write opaque file", F);
			WRITE_TO(TO, "This is a dummy file '%S' created by inprint.\n", mr.exp[0]);
			STREAM_CLOSE(&(br->file_out));
			WRITE("wrote opaque file with dummy contents %f\n", F);
		} else if (Regexp::match(&mr, line, U"file: *(%c+)")) {
			br->file_being_written = Filenames::from_text_relative(br->to, mr.exp[0]);
			text_stream *TO = &(br->file_out);
			if (STREAM_OPEN_TO_FILE(TO, br->file_being_written, UTF8_ENC) == FALSE)
				Errors::fatal_with_file("unable to write file", br->file_being_written);
		} else {
			Errors::in_text_file("unknown command in blueprint file", tfp);
			return;
		}
		Regexp::dispose_of(&mr);		
	}
}
