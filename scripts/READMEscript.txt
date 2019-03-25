@-> ../README.md
# Intest @version(intest)

## About Intest

Intest is a flexible command-line tool for running batches of tests on other
command-line tools. Although it was written for development work on the Inform
programming language (see [ganelson/inform](https://github.com/ganelson/inform)),
it's a general-purpose tool.

Intest is a literate program: it is written in ANSI C, but in the form of
a "web". This means it can either be "tangled" to an executable, or "woven"
to human-readable forms. The woven form is: [&#9733;&nbsp;intest](docs/intest/index.html).

For the Intest manual, see [&#9733;&nbsp;intest/Preliminaries](docs/intest/P-iti).

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

This README.mk file was generated automatically by Inpolicy (see the
[Inform repository](https://github.com/ganelson/inform)), and should not
be edited. To make changes, edit scripts/READMEscript.txt and re-generate.

@-> ../docs/webs.html
@define web(program, manual)
	<li>
		<p>&#9733; <a href="@program/index.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>
		Documentation is <a href="@program/@manual.html">here</a>.</p>
	</li>
@end
@define xweb(program)
	<li>
		<p>&#9733; <a href="@program/index.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>.</p>
	</li>
@end
@define subweb(owner, program)
	<li>
		<p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;↳ &#9733; <a href="@program/index.html"><spon class="sectiontitle">@program</span></a> -
		<span class="purpose">@purpose(@owner/@program)</span></p>
	</li>
@end
@define mod(owner, module)
	<li>
		<p>&nbsp;&nbsp;&nbsp;&nbsp;↳ &#9733; <a href="@module-module/index.html"><spon class="sectiontitle">@module</span></a> (module) -
		<span class="purpose">@purpose(@owner/@module-module)</span></p>
	</li>
@end
@define extweb(program, explanation)
	<li>
		<p>&#9733; <a href="../../@program/docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		@explanation</p>
	</li>
@end
<html>
	<head>
		<title>Inweb &#9733; Webs for ganelson/intest</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="Content-Language" content="en-gb">
		<link href="intest/inweb.css" rel="stylesheet" rev="stylesheet" type="text/css">
	</head>

	<body>
		<ul class="crumbs"><li><a href="https://github.com/ganelson/intest"><b>&#9733 Webs for ganelson/intest</b></a></li></ul>
		<p class="purpose">Human-readable source code.</p>
		<hr>
		<p class="chapter">
This GitHub project was written as a literate program, powered by a LP tool
called Inweb. While almost all programs at Github are open to inspection, most
are difficult for new readers to navigate, and are not structured for extended
reading. By contrast, a "web" (the term goes back to Knuth: see
<a href="https://en.wikipedia.org/wiki/Literate_programming">Wikipedia</a>)
is designed to be read by humans in its "woven" form, and to be compiled or
run by computers in its "tangled" form.
These pages showcase the woven form, and are for human eyes only.</p>
		<hr>
		<p class="chapter">This repository includes just one web:</p>
		<ul class="sectionlist">
			@web('intest', 'P-iti')
		</ul>
	</body>
</html>
