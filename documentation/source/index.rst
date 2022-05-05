.. default-role:: samp
.. highlight:: shell

***************************
The dylan Command-line Tool
***************************

The `dylan` tool provides a number of subcommands to simplify the management of Dylan
workspaces and packages, eliminates the need to manually maintain the "registry" (which
enables the compiler to locate libraries) by hand, and eliminates the need to use git
submodules to track dependencies.

.. toctree::
   :hidden:

   The pacman Package Manager <pacman>

.. contents::
   :depth: 3


Building From Source
====================

In an upcoming release of Open Dylan, the `dylan` tool will be included in the
release. For now, follow these steps to build and install.

.. note::

   Because an executable named "dylan" conflicts with the base Dylan library during the
   build process, this library is named `dylan-tool` and then the executable is installed
   as `dylan` by the `Makefile`. The examples in this document use the name `dylan`
   instead of `dylan-tool`.

1.  Make sure you have `git`, `make`, and `dylan-compiler` installed.

#.  Make sure `git` is on your :envvar:`PATH` so it can be found by the package manager,
    which currently exec's `git clone` to install packages. (This dependency will be
    removed in a future release.)

#.  Optionally set the :envvar:`DYLAN` environment variable to wherever you do your Dylan
    hacking. The `dylan` tool installs packages, including the `pacman-catalog
    <https://github.com/dylan-lang/pacman-catalog>`_ package which describes where to
    find other packages, under `$DYLAN/pkg/`.

    If `$DYLAN` is not set, `$HOME/dylan` is used instead. If for some reason `$HOME` is
    not set, `/opt/dylan` is used. (Windows is not yet supported.)

    .. note::

       Don't put files you want to keep into the `$DYLAN/pkg/` directory. The expectation
       should be that anything in this directory may be deleted at any time by the
       package manager.

#.  Clone and build the `dylan-tool` project::

        $ git clone --recursive https://github.com/dylan-lang/dylan-tool.git
        $ cd dylan-tool
        $ make test
        $ make install

#.  Make sure that `$DYLAN/bin` is on your `$PATH`. If you prefer not to set `$DYLAN`,
    make sure that `$HOME/dylan/bin` is on your `$PATH`.


You should now be able to run ``dylan help`` to see a list of subcommands. To
fully test your installation, try creating a temp workspace and updating
it. Here's an example using the `logging` library::

    $ cd /tmp
    $ dylan new workspace log
    $ cd log
    $ git clone --recursive https://github.com/dylan-lang/logging
    $ dylan update
    $ dylan-compiler -build logging-test-suite   # optional
    $ _build/bin/logging-test-suite              # optional

You should see a lot of output from the ``dylan update`` command. If you run the last two
steps to build the ``logging-test-suite`` library you will see a bunch of compiler
warnings for the core Dylan library, which may be ignored.

.. index::
   single: pacman

Package Manager
===============

The `dylan` tool relies on :doc:`pacman`, the Dylan package manager (unrelated
to the Arch Linux tool), to install dependencies. See :doc:`the pacman
documentation <pacman>` for information on how to define a package, version
syntax, and how dependency resolution works.

Subcommands
===========

.. index::
   single: dylan help subcommand
   single: subcommand; dylan help

dylan help
----------

Use `dylan help`, `dylan help <subcommand>`, or `dylan <subcommand> --help` to get help
on subcommands and options.

.. index::
   single: dylan new workspace subcommand
   single: subcommand; dylan new workspace

dylan new workspace
-------------------

The `new workspace` subcommand creates a new workspace directory and
initializes it with a `workspace.json` file. The workspace name is the only
required argument. ::

  $ dylan new workspace http
  $ cd http
  $ ls -l
  total 8
  -rw-r--r-- 1 you you   28 Dec 29 18:03 workspace.json

Options:
~~~~~~~~

`--directory`
  Create the workspace under this directory instead of the current working
  directory.

.. index::
   single: dylan update subcommand
   single: dylan subcommand; update
   single: subcommand; dylan update
   single: LID file
   single: active package
   single: dependencies
   single: workspace.json file

dylan update
------------

The `update` subcommand be be run from anywhere inside a workspace directory
and performs two actions:

#.  Installs all package dependencies, as specified in their
    `dylan-package.json` files.

#.  Updates the registry to have an entry for each library in the workspace
    packages or their dependencies.

    The `registry` directory is created at the same level as the `workspace.json` file
    and all registry files are written to a subdirectory named after the local platform.

    .. note::

       Registry files are only created if they apply to the architecture of the local
       machine. For example, on `x86_64-linux` LID files that specify `Platforms: win32`
       will not cause a registry file to be generated.

Example:
~~~~~~~~

Create a workspace named `http`, with one active package, `http`, update it, and
build the test suite::

   $ dylan new workspace http
   $ cd http
   $ git clone --recursive https://github.com/dylan-lang/http
   $ dylan update
   $ dylan-compiler -build http-server-test-suite

Note that `dylan-compiler` must always be invoked in the workspace directory so
that it can find the `registry` directory. (This will be easier when the `dylan
build` command is implemented since it will ensure the compiler is invoked in
the right environment.)

.. index::
   single: dylan status subcommand
   single: subcommand; dylan status

dylan new library
-----------------

Generate the boilerplate for a new library, including:

* The library and module definition and initial source files
* A corresponding test suite library and initial source files
* A `dylan-package.json` file

Options:
~~~~~~~~

`--exe`
  Create an executable library. The primary difference is that with this
  flag a `main` function is generated and called.

Here's an example, which assumes you are already inside a Dylan workspace::

  $ dylan new library --exe killer-app
  $ dylan update     # generate registry files, assumes in a workspace
  $ dylan-compiler -build killer-app-test-suite
  $ _build/bin/killer-app-test-suite

You should edit the generated `dylan-package.json` file to set the repository
URL and description for your package, or if this library is part of an existing
package you can just delete `dylan-package.json`.

dylan status
------------

Display the status of the current workspace, including all the active packages.

Options:
~~~~~~~~

`--directory`
  Only show the workspace directory and skip showing the active package.
  This is intended for use by tooling.

Example:
~~~~~~~~

::

    $ dylan-tool status
    I  Downloaded pacman-catalog@master to /home/cgay/dylan/pkg/pacman-catalog/master/src/
    I  Workspace: /home/cgay/dylan/workspaces/dt/
    I  Active packages:
    I    pacman-catalog           : ## master...origin/master
    I    dylan-tool               : ## doc...master (dirty)
    I    pacman                   : ## doc...master [ahead 1]
    I    workspaces               : ## doc...master [ahead 1]


.. index::
   single: dylan install subcommand
   single: subcommand; dylan install

dylan install
-------------

Install a package into the package cache, ``${DYLAN}/pkg``.

.. index::
   single: dylan list subcommand
   single: subcommand; dylan list

dylan list
----------

List installed packages. With the ``--all`` option, list all packages in the catalog.



Index and Search
================

* :ref:`genindex`
* :ref:`search`
