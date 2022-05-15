# Intest 2.1.0

v2.1.0-beta+1A35 'The Remembering' (15 May 2022)

## About Intest

Intest is a flexible command-line tool for running batches of tests on other
command-line tools. Although it was written for development work on the Inform
programming language (see [ganelson/inform](https://github.com/ganelson/inform)),
it's a general-purpose tool.

Intest is a "literate program": it is written as a narrative intended to
be readable by humans as well as by other programs. The human-readable form of
Intest is a [companion website to this one](https://ganelson.github.io/intest/index.html).

For the Intest manual, see [&#9733;&nbsp;intest/Preliminaries](https://ganelson.github.io/intest/intest/M-iti).

## Licence and copyright

Except as noted, copyright in material in this repository (the "Package") is
held by Graham Nelson (the "Author"), who retains copyright so that there is
a single point of reference. As from the first date of this repository
becoming public, 28 April 2022, the Package is placed under the
[Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
This is a highly permissive licence, used by Perl among other notable projects,
recognised by the Open Source Initiative as open and by the Free Software
Foundation as free in both senses.

A condition of any pull-request being made (i.e., to make suggested amendments
to this software) is that, if the request is accepted, copyright on any contribution
made by it immediately transfers to the project's copyright-holder, Graham Nelson.
This is in order that there can be clear ownership.

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

## Reporting Issues

The bug tracker for Intest is powered by Jira and hosted
[at the Atlassian website](https://inform7.atlassian.net/jira/software/c/projects/INTEST/issues).
(Note that Inform, Inweb and Intest are three different projects in Jira: please
do not report Inweb issues on the Inform bug tracker or vice versa.)

The curator of the bug tracker is Brian Rushton, and the administrator is
Hugo Labrande.

## Pull Requests and Adding Features

Intest might well be useful more widely: it's a nice tool to use, and people
are very welcome to try it out.

For now, though, its main function is to verify the Inform suite of software.
Its future direction remains in the hands of the original author.

At some point a more formal process may emerge, but for now community discussion
of possible features is best kept to the IF forum. In particular, please do not
use the bug trackers to propose new features.

Pull requests adding functionality or making any significant changes are therefore
not likely to be accepted from non-members of the wider Inform team without prior
agreement, unless they are clear-cut bug fixes or corrections of typos, broken
links, or similar. See also the note about copyright above.

The Intest licence is highly permissive, and forks which develop in quite different
ways are entirely within the rules. (But one of the few requirements of the
Artistic Licence is that such forks be given a name which is not simply "Intest",
to avoid confusion.)

### Colophon

This README.mk file was generated automatically by Inweb, and should not
be edited. To make changes, edit intest.rmscript and re-generate.

