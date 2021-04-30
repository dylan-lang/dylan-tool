# Dylan Tool

[![Gitter](https://badges.gitter.im/dylan-lang/general.svg)](https://gitter.im/dylan-lang/general?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)


## Overview

The `dylan` tool simplifies the management of Dylan workspaces and packages and
provides a simplified interface to the Open Dylan compiler for building,
testing, and generating documentation. It eliminates the need to manage the
"registry" (for locating libraries) by hand and the need to use git submodules
to track dependencies.

A key part of this tool is the package manager (pacman) and its catalog of
packages, the [pacman-catalog](https://github.com/cgay/pacman-catalog.git)
repository. For any package to be downloadable it must have an entry in the
catalog. The catalog entry specifies the location of the package and its
dependencies, among other attributes.

In addition, a package may have a `pkg.json` file in its top-level
directory. This file, if it exists, overrides dependency information in the
catalog. This is necessary when you need to add a new dependency during
development. When `pkg.json` doesn't exist `dylan` falls back to using
information in the catalog.

A "workspace" is just a directory containing a `workspace.json` file. The
workspace file specifies "active" packages, whuch are the packages you're
actively developing, as opposed to packages installed in the package cache,
`${DYLAN}/pkg/`.

**Note:** Because an executable named `dylan` conflicts with the base Dylan
library during the build process, this library is named `dylan-tool` and then
the executable is installed as `dylan` by the `Makefile`. The examples in this
document use the name `dylan` instead of `dylan-tool`.

## Quick Start

1.  Make sure you have `git`, `make`, and `dylan-compiler` installed.

1.  Optionall set the `DYLAN` environment variable to wherever you do your
    Dylan hacking. The `dylan` tool installs packages, including the
    [pacman-catalog](git@github.com:cgay/pacman-catalog) package which
    describes where to find other packages, under `${DYLAN}/pkg/`.

    If `${DYLAN}` is not set, `${HOME}/dylan` is used instead. If for some
    reason `${HOME}` is not set, `/opt/dylan` is used. (Windows is not yet
    supported.)

    **Note:** Don't put files you want to keep in the `${DYLAN}/pkg/`
    directory. The expectation should be that anything in this directory may be
    deleted at any time by the package manager.

1.  Clone and build the `dylan-tool` project:

        $ git clone --recursive https://github.com/cgay/dylan-tool.git
        $ cd dylan-tool
        $ make install

1.  Make sure that `${DYLAN}/bin` is on your `$PATH`. If you prefer not to set
    `$DYLAN`, make sure that `${HOME}/dylan/bin` is on your `$PATH`.

1.  Create a new workspace. For example if you want to work on the
    strings library:

        $ cd ${DYLAN}/workspaces     # or wherever you want your workspace
        $ dylan new strings strings

    This creates the strings directory and strings/workspace.json.

1.  Run `dylan update` in the new directory to download the active packages
    (the strings package in this case), install their dependencies, and create
    a registry with everything you need:

        $ cd strings
        $ dylan update

    You should see some `git clone` output along with package and registry
    updates.

    **Note:** It should be safe to modify `workspace.json` and run `dylan
    update` at any time from anywhere inside the workspace directory. It will
    only write to the registry and download/install packages that haven't
    already been downloaded or installed.

    **Note:** `dylan update` does not currently update packages that are at
    version "head". If you want the latest head version you must either use
    `git pull` or delete the package directory and run `dylan update` again.

1.  Build and run your code (still in the strings workspace):

        $ dylan-compiler -build strings-test-suite-app
        $ _build/bin/strings-test-suite-app

If you want to create a new package, rather than doing development on one that
already exists, for now you must manually add it to the `workspace.json` file
(see below) and then run `dylan update`. These are the steps:

1.  Create a new directory and git repo for your package in the workspace
    directory. (Hint: use `make-dylan-app` to create a library skeleton.)
1.  Create a `pkg.json` file that lists your package dependencies (deps). You
    could copy from [this
    one](git@github.com:cgay/dylan-tool/blob/master/pkg.json).
1.  Add the package name to the "active" list in the `workspace.json` file.
1.  Run `dylan update` to install the deps and update the registry.

You may run the `dylan` command from anywhere inside the workspace directory
tree; it will search up to find the `workspace.json` file.  You must invoke
`dylan-compiler` in the top-level workspace directory so that all the active
packages are built into the same "_build" directory and so that
`dylan-compiler` can find the auto-generated "registry" directory.

## The Workspace File

A workspace is defined by a `workspace.json` file containing a single
JSON object. Example:

```json
{
    "active": {
        "dylan-tool": {},
        "pacman": {},
        "uncommon-dylan": {}
    },
    "default-library": "dylan-tool"
}
```

(**Note:** There are currently no options so each package name simply maps to
an empty dictionary: `{}`.)

The `"active"` attribute describes the set of packages under active development
in this workspace. These packages are cloned into the workspace directory
rather than in `${DYLAN}/pkg`.

The `"default-library"` attribute is used by the [Dylan LSP
server](https://github.com/pedro-w/lsp-dylan) to decide which project to open.
In general you want this to be your top-level library, or even better its test
library. That is, the one that uses all the other libraries but is not used by
anything in this workspace. That way the LSP server will be able to find all
the code.

If there is only one active package and the library name is the same as the
package name, it will be used as the default library if you omit the
`"default-library"` attribute. Example: `{ "active": { "dylan-tool": {} } }`

After initial checkout you may create a new branch or perform whatever git
operations are necessary. If you decide to add a new dependency, just add it to
the "deps" in `pkg.json` and run `dylan update` again.

Each key under "active" specifies a package under active development. If you're
working on existing packages then these should match the name of an existing
package in the [Catalog](https://github.com/cgay/pacman-catalog.git), and if a
subdirectory by this name doesn't exist in the workspace, `dylan` will do the
initial checkout for you. If you're creating a new package then you'll need to
create the subdirectory yourself, create a `pkg.json` file inside it, and then
run `dylan update` and it will fetch the package's dependencies for you.

## The Registry

Open Dylan uses "registries" to locate library sources. Setting up a
development workspace historically involved a lot of manual git cloning and
creating registry files for each used library.

The main purpose of specifying active packages is so that `dylan` can clone
those packages into the workspace directory and create the registry files for
you accurately.  The registry files point to the workspace directory for active
package libraries but point to the installation directory, `${DYLAN}/pkg/...`,
for all other dependencies.

The `dylan` tool scans each active package for LID files and writes a registry
file for each one, with one exception: If the LID **is included** in another
LID file and **does not** explicitly match the current platform via the
`Platforms:` keyword, then no registry entry is written for that LID file.
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

**Note:** If you use the same workspace directory on multiple platforms (e.g.,
a network mounted directory or shared by a virtual machine) you will need to
run `dylan update` on **both** platforms so that the correct platform-specific
registry entries are created.  The `dylan` tool makes no attempt to figure out
which packages are "generic" and which are platform-specific, so it always
writes registry files specifically for the current platform.

## Bugs

If you have a feature request, think something should be designed
differently, or find bugs, file a bug report
[here](https://github.com/cgay/dylan-tool/issues).

## TODO List

This only lists important items. There are TODOs in the code as well,
but mostly for smaller or less important items. Some of the items on
this list are more for pacman than dylan-tool.

### For 0.1.0

Version 0.1.0 will primarily work with packages at HEAD since that's
the way everyone currently expects to work on Dylan.  Better support
for numbered versions can come later.

* Provide a way to keep packages installed at version "head" up-to-date. Make
  `dylan update` prompt when update is needed, or provide a flag and just print
  a warning.

* Improve output a bit. For example, don't display git clone output
  but do log all events somewhere for debugging purposes.

* Make a standard workspace for developing Open Dylan itself, such
  that it doesn't require the use of any submodules.

  - The airport examples are duplicated in documentation/ and
    dylan-programming/ so they're written to the registry twice and
    the last one "wins". Can one copy be deleted?  Make them into
    their own package? (The main effect of this is some annoying
    output when updating the workspace. Not urgent.)

  - Why didn't collection-extensions get checked out?:
    Wrote /home/cgay/dylan/opendylan.workspace/registry/x86_64-linux/testworks-specs
    No such file or directory: Can't start listing of /home/cgay/dylan/pkg/collection-extensions/head/src/
    No such file or directory: Can't start listing of /home/cgay/dylan/pkg/collection-extensions/head/src/
    Breaking into debugger.
    Trace/breakpoint trap
    Removing the 'head' directory above fixed it. Pretty sure this is from when I C-c'd out
    the first time because I was prompted to enter my ssh key. Need to be resilient to C-c.
    Write a "done" file, when the package download is complete?


### After 0.1.0

* Make the opendylan bootstrap process work with packages. (It's pretty close
  already but has some bugs remaining to work out.)

* Improve version dependency specs. Can get inspiration from Cargo
  here.
