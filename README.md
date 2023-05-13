# Dylan Tool

[![tests](https://github.com/dylan-lang/dylan-tool/actions/workflows/test.yaml/badge.svg)](https://github.com/dylan-lang/dylan-tool/actions/workflows/test.yaml)
[![GitHub issues](https://img.shields.io/github/issues/dylan-lang/dylan-tool?color=blue)](https://github.com/dylan-lang/dylan-tool/issues)
[![Matrix](https://img.shields.io/matrix/dylan-lang-general:matrix.org?color=blue&label=Chat%20on%20Matrix&server_fqdn=matrix.org)](https://app.element.io/#/room/#dylan-language:matrix.org)

The `dylan` tool simplifies the management of Dylan workspaces and packages and
provides a simplified interface to the Open Dylan compiler for building and
(soon) testing, and generating documentation. It eliminates the need to manage
the "registry" (which enables the compiler to locate libraries) by hand and the
need to use git submodules to track dependencies.

A key part of this tool is the package manager (pacman) and its catalog of
packages, the [pacman-catalog](https://github.com/dylan-lang/pacman-catalog)
repository. For any package to be downloadable it must have an entry in the
catalog. The catalog entry specifies the location of the package and what its
dependencies are, among other attributes.

Full documentation is
[here](https://docs.opendylan.org/packages/dylan-tool/documentation/source/index.html).

## Bugs

If you have a feature request, think something should be designed differently, or find
bugs, [file a bug report](https://github.com/dylan-lang/dylan-tool/issues).
