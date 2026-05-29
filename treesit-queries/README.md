# Custom treesit query files

This directory is for custom treesit queries files in Scheme, so that
treesit-jump can work with any files that have a treesitter grammar.

For this to work, init.el needs to modify treesit-jump-queries-extra-alist so
that both these custom queries and the built-in query files are available.
