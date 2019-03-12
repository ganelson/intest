@-> ../README.md
# Intest @version(intest)

## About Intest

Intest is a flexible command-line tool for running batches of tests on other
command-line tools. Although it was written for development work on the Inform
programming language (see [ganelson/inform](https://github.com/ganelson/inform)),
it's a general-purpose tool.

A comprehensive Intest manual can be [read here](docs/intest/P-iti.html).

Intest is a literate program: it is written in ANSI C, but in the form of
a "web". This means it can either be "tangled" to an executable, or "woven"
to human-readable forms. The woven form can [be browsed here](docs/webs.html).

## Build Instructions

* Create a directory to work in, called, say, "work".
* Clone and build Inweb as "work/inweb". Inweb is a literate programming tool,
with its own repository: [ganelson/inweb](https://github.com/ganelson/inweb).
* Clone Intest as "work/intest".
* Change the current directory to "work".
* Run "bash scripts/first.sh" (or whatever shell you prefer: it need
not be bash). This should create a suitable makefile, and then make Intest.
For any future builds, you can simply type "make".
* For a simple test, try e.g. "intest/Tangled/intest -help".
