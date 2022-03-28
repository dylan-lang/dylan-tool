# Dylan Tool

[![Gitter](https://badges.gitter.im/dylan-lang/general.svg)](https://gitter.im/dylan-lang/general?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

**Note:** Because an executable named `dylan` conflicts with the base Dylan
library during the build process, this library is named `dylan-tool` and then
the executable is installed as `dylan` by the `Makefile`. The examples in this
document use the name `dylan` instead of `dylan-tool`.


## Overview and Terminology

The `dylan` tool simplifies the management of Dylan workspaces and packages and
provides a simplified interface to the Open Dylan compiler for building,
testing, and generating documentation. It eliminates the need to manage the
"registry" (which enables the compiler to locate libraries) by hand and the
need to use git submodules to track dependencies.

A key part of this tool is the package manager (pacman) and its catalog of
packages, the [pacman-catalog](https://github.com/dylan-lang/pacman-catalog)
repository. For any package to be downloadable it must have an entry in the
catalog. The catalog entry specifies the location of the package and what its
dependencies are, among other attributes.

A "package" is a bundle of files that can be downloaded as a unit, such as a
Git repository. A package must have a `pkg.json` file in its top-level
directory to define the package attributes, such as name, location, and
dependencies.

A "workspace" is a directory containing a `workspace.json` file and any number
of packages (a.k.a. repositories) checked out into that file's directory.

"Workspace packages" (a.k.a. "active packages") are the packages you're
actively developing. They're checked out in the workspace directory and are
identified by the existence of `pkg.json` in their top-level directory. There
is often only a single workspace package, with a main library and its test
library.

The "package cache" is the directory where package dependencies are installed
and is defined as `${DYLAN}/pkg/`. The `dylan update` command reinstalls needed
dependencies here if they are deleted.


## Quick Start

1.  Make sure you have `git`, `make`, and `dylan-compiler` installed.

1.  Optionally set the `DYLAN` environment variable to wherever you do your
    Dylan hacking. The `dylan` tool installs packages, including the
    [pacman-catalog](https://github.com/dylan-lang/pacman-catalog) package which
    describes where to find other packages, under `${DYLAN}/pkg/`.

    If `${DYLAN}` is not set, `${HOME}/dylan` is used instead. If for some
    reason `${HOME}` is not set, `/opt/dylan` is used. (Windows is not yet
    supported.)

    **WARNING:** Don't put files you want to keep in the `${DYLAN}/pkg/`
    directory. The expectation should be that anything in this directory may be
    deleted at any time by the package manager.

1.  Clone and build the `dylan-tool` project:

        $ git clone --recursive https://github.com/dylan-lang/dylan-tool.git
        $ cd dylan-tool
        $ make install

1.  Make sure that `${DYLAN}/bin` is on your `$PATH`. If you prefer not to set
    `$DYLAN`, make sure that `${HOME}/dylan/bin` is on your `$PATH`.

1.  Create a new workspace. For example if you want to work on the `pacman`
    library:

        $ cd ${DYLAN}/workspaces     # or wherever you want your workspace
        $ dylan new workspace pacman

    A directory named `pacman` and a file named `pacman/workspace.json` are
    created.  In general, the `dylan` command may be run from anywhere inside a
    workspace directory and it will search up for `workspace.json` to determine
    the workspace root.

    Clone the repository (or repositories) you want to work on in this
    workspace.

        $ cd pacman
        $ git clone https://github.com/dylan-lang/pacman

1.  Run `dylan update` to install dependencies and create the registry that
    tells `dylan-compiler` how to find libraries:

        $ dylan update

    The `update` subcommand finds "active" packages in the workspace, and their
    dependencies (or deps), by looking for `pkg.json` files in directories just
    below the workspace directory. In this case the only one is
    `pacman/pkg.json`.

1.  You should now see a `registry` directory in your workspace. Look at the
    generated files:

        $ find registry
        $ cat registry/x86_64-linux/pacman

    (The pathname will be different depending on your host platform.)

1.  Build and run your code (still in the `pacman` workspace directory):

        $ dylan-compiler -build pacman-test-suite
        $ _build/bin/pacman-test-suite

    **Note:** You must invoke `dylan-compiler` in the top-level workspace
    directory so that all the active packages are built into the same "_build"
    directory and so that `dylan-compiler` can find the auto-generated
    "registry" directory.  For example:

        $ cd ${DYLAN}/workspaces/pacman && dylan-compiler -build pacman

If you want to create a new package, rather than doing development on one that
already exists, simply create a new directory for it in the workspace root and
add a `pkg.json` for it. Then run `dylan update` again.

For example, to create a new workspace and package called "protobufs" that uses
the `logging` and `regular-expressions` packages:

1.  `dylan new workspace protobufs`
1.  `cd protobufs`
1.  `dylan new library protobufs`
1.  `cd protobufs`
1.  Edit the `pkg.json` to fill in the required settings and add any necessary
    dependencies. When the file is created by `dylan new library` it should
    look something like this:

        {
            "dependencies": [],
            "description": "** put description here **",
            "name": "protobufs",
            "version": "0.1.0",
            "url": "** put repo url here **"
        }

1.  Run `dylan update` to install the deps and update the registry.
1.  Remember to always run `dylan-compiler` in the workspace root directory.


## The Workspace File

A workspace is defined by a `workspace.json` file. The file must contain `{}`
at a minimum.

```json
{
    "default-library": "strings"
}
```

The `"default-library"` attribute is currently the only valid attribute and is
used by the [Dylan LSP server](https://github.com/dylan-lang/lsp-dylan) to
decide which library to build.  In general the default library should be your
top-level library, or better, its test library. That is, one that uses all the
other libraries but is not used by anything in this workspace. That way the
compiler will generate a complete cross reference database and the LSP server
will be able to find everything.

After initial checkout you may create a new branch or perform whatever git
operations are necessary. If you decide to add a new dependency, just add it to
the "dependencies" in `pkg.json` and run `dylan update` again.


## The Registry

Open Dylan uses "registries" to locate library sources. Setting up a
development workspace historically involved a lot of manual git cloning and
creating registry files for each used library.

The `dylan update` command scans each active package and its dependencies for
`.lid` files and writes a registry file for each one, with an exception for
platform-specific libraries, described below. For simple, pure-Dylan libraries
this is all you need to know and you can skip the next section.

**Note:** If you use the same workspace directory on multiple platforms (e.g.,
a network mounted directory or shared by a virtual machine) you will need to
run `dylan update` on **each** platform so that the correct platform-specific
registry entries are created.  The `dylan` tool makes no attempt to figure out
which packages are "generic" and which are platform-specific, so it always
writes registry files specifically for the current platform.


### Platform-specific Libraries

Open Dylan supports multi-platform libraries via the registry and per-platform
LID files, and to complicate matters one LID file may be included in another
LID file via the `LID:` keyword. In order for `dylan update` to generate the
correct registry files it must figure out which LID files match the current
platform. To accomplish this we introduced the `Platforms:` LID
keyword.

```
Platforms: x86_64-linux
           riscv64-linux
```

If the current platform matches one of the platforms listed in the LID file, a
registry file is generated.

If a LID **is included** in another LID file and **does not** explicitly match
the current platform via the `Platforms:` keyword, then no registry entry is
written for that LID file. The assumption is that the included LID file only
contains shared data and isn't a complete LID file on its own.

This effectively means that if you *include* a LID file in one
platform-specific LID file then you must either create one LID file per
platform for that library, or you must use the `Platforms:` keyword in the
**included** LID file to specify all platforms that *don't* have a
platform-specific LID file.

For example, the base `dylan` library itself (not to be confused with
`dylan-tool`) has a
[dylan-win32.lid](https://github.com/dylan-lang/opendylan/blob/master/sources/dylan/dylan-win32.lid)
file so that it can specify some Windows resource files. `dylan-win32.lid`
includes `dylan.lid` and has `Platforms: x86-win32`. Since there's nothing
platform-specific for any other platform, creating 8 other platform-specific
LID files would be cumbersome. Instead, `dylan.lid` just needs to say which
platforms it explicitly applies to by adding this:

    Platforms: aarch-64-linux
               arm-linux
               x86_64-freebsd
               ...etc, but not x86-win32...

## Bugs

If you have a feature request, think something should be designed differently, or find
bugs, [file a bug report](https://github.com/dylan-lang/dylan-tool/issues).
