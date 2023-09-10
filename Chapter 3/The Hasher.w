[Hasher::] The Hasher.

To optimise by storing MD5 hashes of known-to-be-correct output.

@h Hash values for cases.
In order to support Delia's |hash:| command, we need to be able to assign
each test case a hash value. This will typically be a short hexadecimal string
such as:
= (text)
	64b479d74cd38b887590f139b64ee920
=
The empty text is considered to mean "no cache value known".

=
void Hasher::assign_to_case(test_case *tc, text_stream *hash) {
	tc->known_hash = Str::duplicate(hash);
	LOGIF(HASHER, "determine: %S = %S\n", tc->test_case_name, tc->known_hash);
}

@ We must also be able to detect whether a case has a given hash value.
Two blanks don't make a match, but otherwise they must exactly match, with
case sensitivity and all.

=
int Hasher::compare_hashes(test_case *tc, text_stream *hash) {
	text_stream *known = tc->known_hash;
	if ((Str::len(known) == 0) || (Str::len(hash) == 0)) return FALSE;
	return Str::eq(known, hash);
}

@ Here we extract a single hash value from a one-line file.

=
void Hasher::read_hash(text_stream *V, filename *F) {
	Str::clear(V);
	TextFiles::read(F, FALSE, "can't open md5 hash file", TRUE, &Hasher::detect_hash, NULL, V);
}

void Hasher::detect_hash(text_stream *line_text, text_file_position *tfp, void *vto) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U" *(%C+) *"))
		Str::copy((text_stream *) vto, mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@h The hash cache.
This is the file (for a given project) in which Intest caches all known test
hash values between runs.

=
void Hasher::read_hashes(intest_instructions *args) {
	filename *H = Globals::to_filename(I"hash_cache");
	if (H == NULL) return;
	TextFiles::read(H, FALSE, NULL, FALSE, &Hasher::detect_hashes, NULL, args);
}

void Hasher::detect_hashes(text_stream *line_text, text_file_position *tfp, void *vargs) {
	intest_instructions *args = (intest_instructions *) vargs;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line_text, U"(%c*?) = (%C+)%c*")) {
		test_case *tc = RecipeFiles::find_case(args, mr.exp[0]);
		if (tc) Hasher::assign_to_case(tc, mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
}

@ Once we've finished running, we may know new hashes; here we update the
hash cache in the light of that.

=
void Hasher::write_hashes(void) {
	filename *H = Globals::to_filename(I"hash_cache");
	if (H == NULL) return;

	text_stream TO_struct;
	text_stream *TO = &TO_struct;
	if (STREAM_OPEN_TO_FILE(TO, H, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write file", H);

	LOGIF(HASHER, "Writing hash cache to %f:\n", H);
	test_case *tc;
	LOOP_OVER(tc, test_case)
		if (Str::len(tc->known_hash) > 0) {
			WRITE_TO(TO, "%S = %S\n", tc->test_case_name, tc->known_hash);
			LOGIF(HASHER, "write: %S = %S\n", tc->test_case_name, tc->known_hash);
		}
	STREAM_CLOSE(TO);
}
