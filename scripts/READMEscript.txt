# Intest @var(intest,Version Number)

v@var(intest,Semantic Version Number) '@var(intest,Version Name)' (@var(intest,Build Date))

## About Intest

Intest is a flexible command-line tool for running batches of tests on other
command-line tools. Although it was written for development work on the Inform
programming language (see [ganelson/inform](https://github.com/ganelson/inform)),
it's a general-purpose tool.

Intest is a literate program: it is written in ANSI C, but in the form of
a "web". This means it can either be "tangled" to an executable, or "woven"
to human-readable forms. The woven form is: [&#9733;&nbsp;intest](docs/intest/index.html).

For the Intest manual, see [&#9733;&nbsp;intest/Preliminaries](docs/intest/M-iti).

__Disclaimer__. Because this is a private repository (until the next public
release of Inform, when it will open), its GitHub pages server cannot be
enabled yet. As a result links marked &#9733; lead only to raw HTML
source, not to served web pages. They can in the mean time be browsed offline
as static HTML files stored in "docs".

## Licence

Except as noted, copyright in material in this repository (the "Package") is
held by Graham Nelson (the "Author"), who retains copyright so that there is
a single point of reference. As from the first date of this repository
becoming public, the Package is placed under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
This is a highly permissive licence, used by Perl among other notable projects,
recognised by the Open Source Initiative as open and by the Free Software
Foundation as free in both senses.

## Build Instructions

Make a directory in which to work: let's call this "work". Then:

* Change the current directory to this: "cd work"
* Build Inweb as "work/inweb": see its repository [here](https://github.com/ganelson/inweb)
* Clone Intest: "git clone https://github.com/ganelson/intest.git"
* Perform the initial compilation: "bash intest/scripts/first.sh"
* Test that all is well: "intest/Tangled/intest -help"

You should now have a working copy of Intest. To build it again, simply:
"make -f intest/intest.mk". To test that it's working, try running the test
cases for Inweb: see [Testing Inweb](https://github.com/ganelson/inweb).

### Colophon

This README.mk file was generated automatically by Inweb, and should not
be edited. To make changes, edit scripts/READMEscript.txt and re-generate.
