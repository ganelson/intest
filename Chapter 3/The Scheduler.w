[Scheduler::] The Scheduler.

To queue and then distribute the load of tests.

@h Starting.
At startup, we're told the maximum number of tests we are allowed to conduct
simultaneously.

@d MAX_THREADS 256
@d TRACE_THREADING FALSE /* change this for debugging, if you really must */

=
int use_threads = 1;
void Scheduler::start(int threads_available) {
	if (use_threads > MAX_THREADS) internal_error("too high a thread count");
	use_threads = threads_available;
}

@h Threads and their slots.
There are going to be up to |MAX_THREADS| "work threads" at any one time,
performing the actual tests; together with Intest's main thread, which will
allocate test cases to them and collate the results. The main thread will
usually be asleep while they work, waking every second to see what has
happened since last time.

The simplest option would simply be to divide the tests up equally into
|MAX_THREADS| piles, then start that many work threads, and tell them to
get on with it. This however is inefficient in practice because some tests
take longer than others, so that towards the end of the test run some work
threads would be standing idle, having completed their assignments, while
others -- perhaps even just one -- were still working. That means many of
the processor cores idling towards the end of the run, which is wasteful.

Instead, then, we keep track of |MAX_THREADS| "thread slots". Intest's main
thread will give each slot a small pile of cases to work on, starting a work
thread for each slot to perform those cases. The size of this small pile of
cases is called the |QUANTUM|. When a work thread runs out of things to do,
Intest notices this and gives it some more. (To be more precise, the main
thread stops the original work thread and starts another in the same slot.)

It is not obvious what the best |QUANTUM| value is. A lower |QUANTUM| increases
the likelihood that all processor cores will be fully occupied right to the
end of the testing run, which minimises the time taken. But it also increases
the amount of time lost due to latency on the main thread -- that is, the
fact that the main thread, which wakes only every second, can never react
more quickly than that. If the |QUANTUM| is just 1 and a single test takes
a single core 0.1s to run, then every core will be idle for 0.9s out of
every second.

Experience suggests 16 is a good |QUANTUM| for typical Inform test runs, and
since Inform is our main customer, we'll choose that. If there are 2000 cases
to get through, and 16 thread slots, each thread slot will get through an
average of 125 cases, but it will do it with a succession of about 8 threads
running one after the other. In all, there will have been about 128 test
threads in existence, but only 16 at any one time. Time lost due to latency
then amounts to about 4 seconds per core, times the number of cores: i.e., to
4 seconds in all. (4 because an average of 0.5s is lost each time a thread
finishes, and 8 threads run on each core over the test time.)

@d QUANTUM 16

@

@d NO_THREAD 1       /* this slot has no thread running */
@d WORKING_THREAD 2  /* this slot has a thread which hasn't finished work */
@d IDLE_THREAD 3     /* this slot has a thread which has finished and is idle */

=
typedef struct thread_slot {
	int availability; /* one of the three |*_THREAD| values above */
	struct filename *slot_log_name; /* local-to-this-slot debugging log name */
	struct text_stream split_log; /* local-to-this-slot debugging log */
	foundation_thread work_thread; /* has no valid contents if |NO_THREAD| */
	foundation_thread_attributes attributes; /* similarly */
	struct pathname *sandbox; /* a safe area for threads in this slot to create files */
	int counter;
} thread_slot;

thread_slot thread_slots[MAX_THREADS];

@ Each thread slot is provided with its own sandbox directory in the file
system, where it can if it wishes create files. These are subdirectories
called |T0|, |T1|, ... in the directory pointed to by the global variable
|$$workspace|. (Note: if you change this, be sure to make a matching change
to the Skein-reading code.)

=
void Scheduler::initialise_slots(void) {
	for (int s = 0; s < use_threads; s++) {
		thread_slots[s].counter = s;
		thread_slots[s].availability = NO_THREAD;
		TEMPORARY_TEXT(FNAME);
		WRITE_TO(FNAME, "debug-log-thread-%d.txt", s);
		pathname *Thread_Work_Area = Scheduler::work_area(s);
		thread_slots[s].slot_log_name = Filenames::in(Thread_Work_Area, FNAME);
		DISCARD_TEXT(FNAME);
	}
	if (use_threads > 0) Scheduler::work_area(0);
}

int sandboxes_made = FALSE;
pathname *Scheduler::work_area(int s) {
	if ((s<0) || (s>=use_threads)) internal_error("thread slot out of range");
	if (sandboxes_made == FALSE) {
		sandboxes_made = TRUE;
		for (int t = 0; t < use_threads; t++) {
			TEMPORARY_TEXT(TN);
			WRITE_TO(TN, "T%d", t);
			pathname *workspace = Globals::to_pathname(I"workspace");
			thread_slots[t].sandbox = Pathnames::down(workspace, TN);
			DISCARD_TEXT(TN);
		}
	}
	return thread_slots[s].sandbox;
}

@ This is the only place in Intest where we invoke the dark magic of pthread
library calls. The main Intest thread will call |pthread_create| to
call a function, always |Scheduler::perform_work|, on a new thread.
When that function "returns", however, its thread does not cease to exist.
That happens only when the main Intest thread calls |pthread_join| on it.
"Create" and "join" are, in effect, pthread jargon for "start" and "stop".

We clearly need some way for a work thread to signal back when it is
finished, as otherwise there will be no way for the main thread to know when
it is safe to join it. We do that with the |availability| field in the slot
structure: when the working thread has done all its work, that thread sets
|availability| to |IDLE_THREAD|. It then becomes quiescent. Once every second
the main thread looks to see if any slots have become idle, and if so, it
then joins their threads.

As elegant as the Unix pthread model is, it's unfortunate that we are
expected to specify explicitly what stack size to allocate our work threads.
We will simply choose a Very Big Number and hope for the best.

@d STACK_SIZE_PER_WORK_THREAD 0x8000000

=
void Scheduler::start_work_on_slot(int s) {
	if (thread_slots[s].availability != NO_THREAD)
		internal_error("tried to start second thread in same slot");
	thread_slots[s].availability = WORKING_THREAD;
	Platform::init_thread(&thread_slots[s].attributes, STACK_SIZE_PER_WORK_THREAD);
	if (TRACE_THREADING) {
		PRINT("Work on slot %d: ", s);
		test *T;
		LOOP_OVER(T, test)
			if (T->allocated_to == s) {
				PRINT("T%d:%S ", T->allocation_id, T->to_be_tested->test_case_name);
			}
		PRINT("\n");
	}
	int rc = Platform::create_thread(&(thread_slots[s].work_thread),
		&(thread_slots[s].attributes),
		Scheduler::perform_work,
		(void *) &(thread_slots[s].counter));
	if (rc == EAGAIN) internal_error("thread failed EAGAIN");
	if (rc == EINVAL) internal_error("thread failed EINVAL");
	if (rc == EPERM) internal_error("thread failed EPERM");
	if (rc != 0) internal_error("thread failed");
}

void Scheduler::stop_work_on_slot(int s) {
	int rc = Platform::join_thread(thread_slots[s].work_thread, NULL);
	if (rc != 0) internal_error("thread failed to join");
	thread_slots[s].availability = NO_THREAD;	
}

size_t Scheduler::stack_size(int s) {
	return Platform::get_thread_stack_size(&(thread_slots[s].attributes));
}

@ =
void Scheduler::stop_work_on_idle_slots(void) {
	for (int s = 0; s < use_threads; s++)
		if (thread_slots[s].availability == IDLE_THREAD)
			Scheduler::stop_work_on_slot(s);
}

void Scheduler::stop_work_on_all_slots(void) {
	for (int s = 0; s < use_threads; s++)
		if (thread_slots[s].availability != NO_THREAD)
			Scheduler::stop_work_on_slot(s);
}

@h Scheduling.
The scheduler completes one of the following structures for each test
performed: it's a form holding what to do and what the results were. For
now, scheduling consists of creating the structure with the results left
blank.

@d NO_SLOT_AS_YET -1
@d DONE_AND_NO_LONGER_NEEDS_SLOT -2

@ =
typedef struct test {
	struct test_case *to_be_tested;
	int action_type; /* for example, |TEST_ACTION| or |BLESS_ACTION| */
	struct filename *redirect; /* where to redirect console output */
	int allocated_to; /* an index into |thread_slots|, or else one of the values above */
	int passed; /* or |NOT_APPLICABLE| if not yet run */
	struct text_stream *full_results;
	struct test *previous_completed_test;
	MEMORY_MANAGEMENT
} test;


void Scheduler::schedule(test_case *tc, filename *redirect, int test_action) {
	if (tc == NULL) internal_error("no test case");
	test *T = CREATE(test);
	T->to_be_tested = tc;
	T->redirect = redirect;
	T->allocated_to = NO_SLOT_AS_YET;
	T->passed = NOT_APPLICABLE;
	T->action_type = test_action;
	T->full_results = Str::new_with_capacity(20480);
	T->previous_completed_test = NULL;
}

@h Distributing.
We will maintain a reverse linked list which holds the tests in the sequence
in which they completed -- almost certainly out of their original scheduling
order, and sometimes drastically so. |last_completed_test| is always the
most recent.

=
test *last_completed_test = NULL;
int splitting_logs = FALSE;

void Scheduler::test(OUTPUT_STREAM) {
	if (NUMBER_CREATED(test) == 0) return;
	Scheduler::initialise_slots();
	text_stream *main_DL = DL;
	if (Log::aspect_switched_on(TESTER_DA)) splitting_logs = TRUE;
	if (splitting_logs) @<Split the debugging log into forks per thread@>;
	time_t time_at_start = time(0);
	@<Allocate and run the tests@>;
	time_t duration = time(0) - time_at_start;
	if (splitting_logs) @<Unsplit the debugging log@>;
	if (splitting_logs) splitting_logs = FALSE;
	@<Write results banner@>;
}

@<Split the debugging log into forks per thread@> =
	LOGIF(TESTER, "Splitting into independent debugging logs per thread here\n");
	Log::close();
	for (int s = 0; s < use_threads; s++) {
		Log::open_alternative(
			thread_slots[s].slot_log_name, &(thread_slots[s].split_log));
		LOG("This log belongs to thread %d\n", s);
		DL = NULL;
	}

@<Unsplit the debugging log@> =
	for (int s = 0; s < use_threads; s++)
		Streams::close(&(thread_slots[s].split_log));
	DL = main_DL;
	LOGIF(TESTER, "Back to a single debugging log here\n");

@ The loop here, which of course runs on the main thread, sleeps for 1 second
with each iteration.

@<Allocate and run the tests@> =
	last_completed_test = NULL;
	int line_complete = TRUE, current_wildcard = ALL_WILDCARD;
	test *next_to_report = FIRST_OBJECT(test);
	test *next_test_to_allocate = next_to_report;
	int number_still_to_allocate = NUMBER_CREATED(test);
	while (next_to_report) {
		STREAM_FLUSH(OUT);
		Scheduler::stop_work_on_idle_slots();
		@<Allocate next few tests@>;
		@<Gather up recent reports@>;
		Platform::sleep(1);
	}
	if (line_complete == FALSE) { line_complete = TRUE; WRITE("\n"); }
	Scheduler::stop_work_on_all_slots();

@ We make a list of all thread slots currently standing idle, and then
allocate them each a roughly equal number of the test cases not yet
allocated to any slot; but we stop when they have |QUANTUM| number of
cases to look at.

@<Allocate next few tests@> =
	int free_slot_list[MAX_THREADS], given_over[MAX_THREADS];
	int threads_free = 0;
	for (int s = 0; s < use_threads; s++) {
		if (thread_slots[s].availability == NO_THREAD) {
			free_slot_list[threads_free] = s;
			given_over[threads_free++] = 0;
		}
	}
	if ((threads_free > 0) && (number_still_to_allocate > 0)) {
		@<Give each free slot up to QUANTUM-many test cases to work on@>;
		@<For each slot which which was given any, start a work thread@>;
		if (TRACE_THREADING) printf("Still to allocate: %d\n", number_still_to_allocate);
	}

@<Give each free slot up to QUANTUM-many test cases to work on@> =
	int c = 0;
	while (next_test_to_allocate) {
		int s = free_slot_list[c % threads_free];
		if (given_over[c % threads_free] >= QUANTUM) break;
		next_test_to_allocate->allocated_to = s;
		given_over[c % threads_free]++;
		number_still_to_allocate--; c++;
		next_test_to_allocate = NEXT_OBJECT(next_test_to_allocate, test);
	}

@<For each slot which which was given any, start a work thread@> =
	for (int c = 0; c < threads_free; c++)
		if (given_over[c] > 0) {
			if (TRACE_THREADING)
				printf("starting work thread on slot %d to perform %d tests\n",
					free_slot_list[c], given_over[c]);
			Scheduler::start_work_on_slot(free_slot_list[c]);
		}

@ The only purpose of the following is to print something to the terminal so
that the user has some comforting evidence that work is going on. This is
where Intest's familiar chains of bracketed case numbers are printed:
= (text)
	inter -> cases: [1] [2] [3] [4] [5] [6] [7] (8) [9] [10] -11- [12] [13]
=
Note that they are grouped by "wildcard", in effect, by their case type.
The symbols placed either side of the case number, loosely called its
"brackets", are chosen by the Tester on the basis of the test's outcome.

@<Gather up recent reports@> =
	while ((next_to_report) &&
		(next_to_report->allocated_to == DONE_AND_NO_LONGER_NEEDS_SLOT)) {
		test *T = next_to_report;
		int w = Actions::which_wildcard(T->to_be_tested);
		if (w != current_wildcard) {
			current_wildcard = w;
			if (line_complete == FALSE) { line_complete = TRUE; WRITE("\n"); }
			WRITE("%p -> %s: ", home_project, Actions::name_of_wildcard(w));
			line_complete = FALSE;
		}
		if (T->passed) {
			line_complete = FALSE;
			WRITE("%c%d%c ", T->to_be_tested->left_bracket, T->allocation_id + 1,
				T->to_be_tested->right_bracket);
		} else {
			if (line_complete == FALSE) { line_complete = TRUE; WRITE("\n"); }
			WRITE("%S", T->full_results);
		}
		next_to_report = NEXT_OBJECT(next_to_report, test);
	}
	STREAM_FLUSH(OUT);

@ And, now the hurly-burly's done: now the battle's lost and won. We need to
print out the summary of what happened, e.g.:
= (text)
	All 27 tests succeeded (time taken 0:02, 16 simultaneous threads)
=
The "bottom line" text here is "All 27 tests succeeded".

@<Write results banner@> =
	int successes = 0, failures = 0;
	test *T;
	LOOP_OVER(T, test) {
		if (T->passed == TRUE) successes++;
		if (T->passed == FALSE) failures++;
	}
	int N = use_threads;
	if (N > successes + failures) N = successes + failures;

	TEMPORARY_TEXT(bottom_line);
	@<And the bottom line is...@>;
	if (failures > 0) @<Recite our failures@>;
	if (successes + failures >= 10)
		Platform::notification(bottom_line, (failures == 0)?TRUE:FALSE);
	DISCARD_TEXT(bottom_line);

@<And the bottom line is...@> =
	switch (successes + failures) {
		case 1:
			if (successes == 0) WRITE_TO(bottom_line, "Failed");
			else WRITE_TO(bottom_line, "Succeeded");
			break;
		case 2:
			if (successes == 0) WRITE_TO(bottom_line, "Both tests failed");
			else if (failures == 0) WRITE_TO(bottom_line, "Both tests succeeded");
			else WRITE_TO(bottom_line, "%d test succeeded but %d failed", successes, failures);
			break;
		default:
			if (successes == 0) WRITE_TO(bottom_line, "All %d tests failed", failures);
			else if (failures == 0) WRITE_TO(bottom_line, "All %d tests succeeded", successes);
			else WRITE_TO(bottom_line, "%d test%s succeeded but %d failed",
				successes, (successes==1)?"":"s", failures);
			break;
	}
	WRITE("  %S (time taken %d:%02d",
		bottom_line, ((int) duration)/60, ((int) duration)%60);
	if (N > 1) {
		WRITE(", %d simultaneous thread%s", N, (N==1)?"":"s");
	}
	WRITE(")\n");

@ This does more than simply print the names of test cases which failed: it
also tells the Historian to give them numbered shortcut names in future.

@<Recite our failures@> =
	WRITE("Failed:");
	Historian::notify_failure_count(failures);
	int f = 0;
	LOOP_OVER(T, test)
		if (T->passed == FALSE) {
			WRITE(" %d=%S", f+1, T->to_be_tested->test_case_name);
			Historian::notify_failure(f++, T->to_be_tested->test_case_name);
		}
	WRITE("\n");

@h Work threads begin here.
When a work thread is created, this is its function. The one argument is a
pointer to an integer, which tells us which slot number we are running in.

=
void *Scheduler::perform_work(void *argument) {
	int s = *((int *) argument);
	if (Log::aspect_switched_on(TESTER_DA))
		LOG("Thread in slot %d has stack size %08x\n",
			s, Scheduler::stack_size(s));
	test *T;
	LOOP_OVER(T, test)
		if (T->allocated_to == s) {
			int result = Tester::test(T->full_results, T->to_be_tested,
				T->allocation_id + 1, s, T->action_type);
			@<Mark test T as completed@>;
		}
	if (TRACE_THREADING) printf("(Thread in slot %d has finished.)\n", s);
	thread_slots[s].availability = IDLE_THREAD;
	return NULL;
}

@ The mutex here is needed because there is just one global reverse linked
list of completed texts: if two threads were simultaneously changing the
value of |last_completed_test|, disaster would befall us. This is so
unlikely to happen that the mutex here is about like taking insurance out
against asteroid impacts, but still, one likes to be safe.

@<Mark test T as completed@> =
	T->passed = result;
	T->allocated_to = DONE_AND_NO_LONGER_NEEDS_SLOT;

	CREATE_MUTEX(mutex);
	LOCK_MUTEX(mutex);
		T->previous_completed_test = last_completed_test;
		last_completed_test = T;
	UNLOCK_MUTEX(mutex);
