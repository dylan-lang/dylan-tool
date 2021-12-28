.. default-role:: samp
.. highlight:: shell

The `dylan` tool provides a number of subcommands to simplify the management of Dylan
workspaces and packages, eliminates the need to manually maintain the "registry" (which
enables the compiler to locate libraries) by hand, and eliminates the need to use git
submodules to track dependencies.

.. contents::
   :depth: 2


Build dylan tool from source
============================

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
        $ make install

#.  Make sure that `$DYLAN/bin` is on your `$PATH`. If you prefer not to set `$DYLAN`,
    make sure that `$HOME/dylan/bin` is on your `$PATH`.


You should now be able to run ``dylan help`` to see a list of subcommands. To
fully test your installation, try creating a temp workspace and updating
it. Here's an example using the `logging` library::

    $ cd /tmp
    $ dylan new workspace my-workspace
    $ cd my-workspace
    $ git clone --recursive https://github.com/dylan-lang/logging
    $ dylan update
    $ dylan-compiler -build logging-test-suite   # optional
    $ _build/bin/logging-test-suite              # optional

You should see a lot of output from the ``dylan update`` command. If you run the last two
steps to build the ``logging-test-suite`` library you will see a bunch of compiler
warnings for the core Dylan library, which may be ignored.

.. note::

   **TODO:** Write pacman docs and point to them here so people can get a basic
   understanding of

     - what the versioning scheme is
     - what syntax is valid for specifying deps
     - how deps are resolved
     - what pkg.json is for and what its syntax is
     - how to add their package to the catalog




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

The `update` subcommand must be run inside a workspace directory and performs two actions:

#.  Installs all package dependencies, as specified in their `pkg.json` files.

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
that it can find the `registry` directory.

.. index::
   single: dylan status subcommand
   single: subcommand; dylan status

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
