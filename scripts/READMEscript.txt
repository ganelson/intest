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
* Run "bash intest/scripts/first.sh" (or whatever shell you prefer: it need
not be bash). This should create a suitable makefile, and then make Intest.
For any future builds, it is enough to "make -f intest/intest.mk".
* For a simple test, try "intest/Tangled/intest -help".
@-> ../docs/webs.html
@define web(program, manual)
	<li>
		<p><a href="@program/index.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>
		Documentation is <a href="@program/@manual.html">here</a>.</p>
	</li>
@end
@define subweb(owner, program)
	<li>
		<p>↳ <a href="docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		<span class="purpose">@purpose(@owner/@program)</span></p>
	</li>
@end
@define mod(owner, module)
	<li>
		<p>↳ <a href="docs/@module-module/index.html"><spon class="sectiontitle">@module</span></a> (module) -
		<span class="purpose">@purpose(@owner/@module-module)</span></p>
	</li>
@end
@define extweb(program)
	<li>
		<p><a href="../@program/docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>
		This has its own repository, with its own &#9733; Webs page.</p>
	</li>
@end
@define extsubweb(owner, program)
	<li>
		<p>↳ <a href="../@owner/docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		<span class="purpose">@purpose(@owner/@program)</span></p>
	</li>
@end
@define extmod(owner, module)
	<li>
		<p>↳ <a href="../@owner/docs/@module-module/index.html"><spon class="sectiontitle">@module</span></a> (module) -
		<span class="purpose">@purpose(@owner/@module-module)</span></p>
	</li>
@end
<html>
	<head>
		<title>Inform &#9733; Webs</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="Content-Language" content="en-gb">
		<link href="intest/inweb.css" rel="stylesheet" rev="stylesheet" type="text/css">
	</head>

	<body>
		<ul class="crumbs"><li><b>&#9733;</b></li><li><b>Webs</b></li></ul>
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
