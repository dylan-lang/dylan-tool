.. highlight:: shell

***************************
The dylan Command-line Tool
***************************

The ``dylan`` command-line tool provides a number of subcommands to simplify
the management of Dylan workspaces and package dependencies, eliminates the
need to manually maintain the "registry" (which enables the compiler to locate
libraries) by hand, and eliminates the need to use git submodules to track
dependencies.

.. toctree::
   :hidden:

   The pacman Package Manager <pacman>

.. contents::
   :depth: 3


Terminology
===========

package
  A blob of files that can be unpacked into a directory and which has a
  ``dylan-package.json`` file in the top-level directory which describes its
  attributes. A package currently corresponds to a single Git repository. A
  package has a set of versioned releases.

workspace
  A directory containing a ``workspace.json`` file. Most ``dylan`` commands may be
  run from anywhere within the workspace directory.

active package
  A package checked out into the top-level of a workspace. Active packages are
  found by looking for ``<workspace>/*/dylan-package.json`` files. The ``update``
  subcommand scans active packages when creating the registry.

release
  A specific version of a package. A release has a `Semantic Version`_ associated
  with it, such as ``0.5.0``.


Requirements
============

To find and install packages on the local file system many of the ``dylan``
subcommands use the :envvar:`DYLAN` environment variable. If :envvar:`DYLAN` is
not set, ``$HOME/dylan`` is used instead. (Much of this documentation is written
to assume that :envvar:`DYLAN` is set, but it is not required.)

Make sure ``git`` is on your :envvar:`PATH` so it can be found by the package
manager, which currently exec's ``git clone`` to install packages. (This
dependency will be removed in a future release.)

The ``dylan`` tool installs packages, including the `pacman-catalog`_ package
which describes where to find other packages, under ``$DYLAN/pkg/``.

.. warning::

   Don't put files you want to keep into the ``$DYLAN/pkg/`` directory. The
   expectation should be that anything in this directory may be deleted at any
   time by the package manager.


Building From Source
====================

In an upcoming release of Open Dylan, the ``dylan`` tool will be included in the
release. For now, follow these steps to build and install.

.. note:: Because an executable named "dylan" conflicts with the base Dylan
   library during the build process, this library is named ``dylan-tool`` and
   then the executable is installed as ``dylan`` by the ``Makefile``. The
   examples in this document use the name ``dylan`` instead of ``dylan-tool``.

#.  Read the `Requirements`_ section, above.

#.  Make sure you have ``git``, ``make``, and ``dylan-compiler`` installed.

#.  Clone and build the ``dylan-tool`` project::

        $ git clone --recursive https://github.com/dylan-lang/dylan-tool.git
        $ cd dylan-tool
        $ make
        $ make test      # optional
        $ make install

#.  Make sure that ``$DYLAN/bin`` is on your ``$PATH``. If you prefer not to
    set ``$DYLAN``, make sure that ``$HOME/dylan/bin`` is on your ``$PATH``.

You should now be able to run the Hello World example, below.


Hello World
===========

To make sure everything is working correctly, and to get a quick sense of
what's available, start by running the ``dylan help`` command.

To fully test your installation, try creating a temp workspace and updating
it. Here's an example that makes a workspace with one active package,
"logging"::

    $ cd /tmp
    $ dylan new workspace log
    $ cd log
    $ git clone --recursive https://github.com/dylan-lang/logging
    $ dylan update
    $ dylan-compiler -build logging-test-suite   # optional
    $ _build/bin/logging-test-suite              # optional

You should see some output from the ``dylan update`` command including the
location of the registry directory and any dependencies it downloads. If you
run the last two steps to build the ``logging-test-suite`` library you will see
a bunch of compiler warnings for the core Dylan library, which may be ignored.

.. index::
   single: pacman


Package Manager
===============

The ``dylan`` tool relies on :doc:`pacman`, the Dylan package manager
(unrelated to the Arch Linux tool by the same name), to install
dependencies. See :doc:`the pacman documentation <pacman>` for information on
how to define a package, version syntax, and how dependency resolution works.

Global Options
==============

Note that global command line options must be specified between "dylan" and the
first subcommand name. Example: ``dylan --debug new library --exe my-lib``

``--debug``
  Disables error handling so that when an error occurs the debugger will be
  entered, or if not running under a debugger a stack trace will be printed.
  When used with the ``--verbose`` flag this also enabled tracing of dependency
  resolution.

``--verbose``
  Enables more verbose output, such as displaying which packages are
  downloaded, which registry files are written, etc.

  When used with the ``--debug`` flag this also enabled tracing of dependency
  resolution.


Subcommands
===========


.. index::
   single: dylan help subcommand
   single: subcommand; dylan help

dylan help
----------

Displays overall help or help for a specific subcommand.

Synopsis:
  ``dylan help``

  ``dylan help <subcommand> [<sub-subcommand> ...]``

  ``dylan <subcommand> [<sub-subcommand> ...] --help``


.. index::
   single: dylan install subcommand
   single: subcommand; dylan install

dylan install
-------------

Install a package into the package cache, ``${DYLAN}/pkg``.

Synopsis: ``dylan install <package> [<package> ...]``

This command is primarily useful if you want to browse the source code in a
package locally without having to worry about where to clone it from. The
packages are installed into ``${DYLAN}/pkg/<package-name>/<version>/src/``.


.. index::
   single: dylan list subcommand
   single: subcommand; dylan list

.. _dylan-list:

dylan list
----------

Display a list of installed packages along with the latest installed version
number and the latest version available in the catalog, plus a short
description. With the ``--all`` option, list all packages in the catalog
whether installed or not.

An asterisk is displayed next to packages for which the latest installed 

Example::

   $ dylan list
        Inst.   Latest  Package               Description
        0.1.0    0.1.0  base64                Base64 encoding
      * 3.1.0    3.2.0  command-line-parser   Parse command line flags and subcommands
        0.1.0    0.1.0  concurrency           Concurrency utilities
        0.6.0    0.6.0  dylan-tool            Manage Dylan workspaces, packages, and registries
        ...


.. index::
   single: dylan new library subcommand
   single: subcommand; dylan new library

dylan new library
-----------------

Generate the boilerplate for a new library.

Synopsis: ``dylan new library [options] <library-name> [<dependency> ...]``

Specifying dependencies is optional. They should be in the same form as
specified in the ``dylan-package.json`` file.

This command generates the following code:

* A main library and module definition and initial source files
* A corresponding test suite library and initial source files
* A ``dylan-package.json`` file

Unlike the ``make-dylan-app`` binary included with Open Dylan, this command
does not generate a "registry" directory. Instead, it is expected that you will
run ``dylan update`` to generate the registry.

Options:
~~~~~~~~

``--exe``
  Create an executable library (with a ``main`` function and a top-level call
  to that function) in addition to a shared library. Generally the ``main``
  function does little more than parse command-line arguments and then calls
  code in the shared library. The shared library is used by the executable
  library and by the test suite.

Here's an example of creating an executable named "killer-app" which depends on
http version 1.0 and the latest version of logging. It assumes you are in the
top-level directory of a Dylan workspace. ::

  $ dylan new library --exe killer-app http@1.0 logging
  $ dylan update     # generate registry files, assumes in a workspace
  $ dylan-compiler -build killer-app-test-suite
  $ _build/bin/killer-app-test-suite

Edit the generated ``dylan-package.json`` file to set the repository URL,
description, and other attributes for your package.


.. index::
   single: dylan new workspace subcommand
   single: subcommand; dylan new workspace

dylan new workspace
-------------------

Create a new workspace.

Synopsis: ``dylan new workspace [options] <workspace-name>``

Options:
~~~~~~~~

``--directory``
  Create the workspace under this directory instead of in the current working
  directory.

The ``new workspace`` subcommand creates a new workspace directory and
initializes it with a ``workspace.json`` file. The workspace name is the only
required argument. Example::

  $ dylan new workspace my-app
  $ cd my-app
  $ ls -l
  total 8
  -rw-r--r-- 1 you you   28 Dec 29 18:03 workspace.json

Clone repositories in the top-level workspace directory to create active
packages, then run `dylan update`_.


.. index::
   single: dylan publish subcommand
   single: subcommand; dylan publish

dylan publish
-------------

The ``publish`` command adds a new release of a package to the package catalog.

Synopsis: ``dylan publish <package-name>``

.. note:: For now, until a fully automated solution is implemented, it works by
   modifying the local copy of the catalog so that you can manually run the
   `pacman-catalog`_ tests and submit a pull request. This eliminates a lot of
   possibilities for making mistakes while editing the catalog by hand.

This command may (as usual) be run from anywhere inside a workspace. Once
you're satisfied that you're ready to release a new version of your package
(tests pass, doc updated, etc.) follow these steps:

#.  Update the ``"version"`` attribute in ``dylan-package.json`` to be the new
    release's version, commit the change, and push it to your main branch.

#.  Make a new release on GitHub with a tag that matches the release version.
    For example, if the ``"version"`` attribute in ``dylan-package.json`` is
    ``"0.5.0"`` the GitHub release should be tagged ``v0.5.0``.

#.  Run ``dylan publish my-package``.  (If `pacman-catalog`_ isn't already an
    active package in your workspace the command will abort and give you
    instructions how to fix it.)

#.  Commit the changes to `pacman-catalog`_ and submit a pull request.  The
    tests to verify the catalog will be run automatically by the GitHub CI.

#.  Once your PR has been merged, verify that the package is available in the
    catalog by running ``dylan install my-package@0.5.0``, substituting your
    new release name and version.

#.  It's generally good practice to update the version immediately after
    publishing a release so that it reflects the *next* release's version
    number. See :ref:`package-versions` for more on this.


.. index::
   single: dylan status subcommand
   single: subcommand; dylan status

dylan status
------------

Display the status of the current workspace.

Synopsis: ``dylan status``

Options:
~~~~~~~~

``--directory``
  Only show the workspace directory and skip showing the active packages.
  This is intended for use by tooling.

Example:
~~~~~~~~

::

    $ dylan status
    Workspace: /home/cgay/dylan/workspaces/dt/
    Active packages:
      http                     : ## master...origin/master (dirty)
      dylan-tool               : ## dev...master [ahead 2] (dirty)
      pacman-catalog           : ## publish...master [ahead 1] (dirty)


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

Update the workspace based on the current set of active packages.

Synopsis: ``dylan update``

The ``update`` command may be run from anywhere inside a workspace directory
and performs two actions:

#.  Installs all active package dependencies, as specified in their
    `dylan-package.json` files. Any time these dependencies are changed you
    should run ``dylan update`` again.

#.  Updates the registry to have an entry for each library in the workspace's
    active packages or their dependencies.

    The ``registry`` directory is created at the same level as the
    ``workspace.json`` file and all registry files are written to a
    subdirectory named after the local platform.

    If a dependency is also an active package in this workspace, the active
    package is preferred over the specific version listed as a dependency.

    .. note:: Registry files are only created if they apply to the architecture
       of the local machine. For example, on ``x86_64-linux`` LID files that
       specify ``Platforms: win32`` will not cause a registry file to be
       generated.

Example:
~~~~~~~~

Create a workspace named ``dt``, with one active package, ``dylan-tool``,
update it, and build the test suite::

   $ dylan new workspace dt
   $ cd dt
   $ git clone --recursive https://github.com/dylan-lang/dylan-tool
   $ dylan update
   $ dylan-compiler -build dylan-tool-test-suite

Note that ``dylan-compiler`` must always be invoked in the workspace directory
so that it can find the ``registry`` directory. (This will be easier when the
``dylan build`` command is implemented since it will ensure the compiler is
invoked in the right environment.)


.. index::
   single: dylan version subcommand
   single: subcommand; dylan version

dylan version
-------------

Show the version of the ``dylan`` command you are using. This is the Git
version from which `dylan-tool <https://github.com/dylan-lang/dylan-tool>`_
was compiled.

Synopsis: ``dylan version``


Index and Search
================

* :ref:`genindex`
* :ref:`search`


.. _pacman-catalog:    https://github.com/dylan-lang/pacman-catalog.git
.. _semantic version:  https://semver.org/spec/v2.0.0.html
