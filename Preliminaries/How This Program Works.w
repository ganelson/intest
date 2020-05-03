How This Program Works.

An overview of how Intest works, with links to all of its important functions.

@h Prerequisites.
This page is to help readers to get their bearings in the source code for
Inweb, which is a literate program or "web". Before diving in:
(a) It helps to have some experience of reading webs: see //inweb// for more.
(b) Intest is written in C, in fact ANSI C99, but this is disguised by the
fact that it uses some extension syntaxes provided by the //inweb// literate
programming tool, making it a dialect of C called InC. See //inweb// for
full details, but essentially: it's C without predeclarations or header files,
and where functions have names like |Tags::add_by_name| rather than just |add_by_name|.
(c) Intest makes use of a "module" of utility functions called //foundation//.
This is a web in its own right. There's no need to read it in full, but if
you haven't seen a Foundation-based program before, you may want to take a
quick look at //foundation: A Brief Guide to Foundation//.
