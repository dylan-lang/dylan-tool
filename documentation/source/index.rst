.. highlight:: shell

***************************
The dylan Command-line Tool
***************************

The `dylan`` tool provides a number of subcommands to simplify the management of Dylan
workspaces and packages, eliminates the need to manually maintain the "registry" (which
enables the compiler to locate libraries) by hand, and eliminates the need to use git
submodules to track dependencies.

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

The ``dylan`` tool installs packages, including the `pacman-catalog
<https://github.com/dylan-lang/pacman-catalog>`_ package which describes where
to find other packages, under ``$DYLAN/pkg/``.

.. warning::

   Don't put files you want to keep into the ``$DYLAN/pkg/`` directory. The
   expectation should be that anything in this directory may be deleted at any
   time by the package manager.


Building From Source
====================

In an upcoming release of Open Dylan, the ``dylan`` tool will be included in the
release. For now, follow these steps to build and install.

.. note::

   Because an executable named "dylan" conflicts with the base Dylan library during the
   build process, this library is named ``dylan-tool`` and then the executable is installed
   as ``dylan`` by the ``Makefile``. The examples in this document use the name ``dylan``
   instead of ``dylan-tool``.

#.  Read the `Requirements`_ section, above.

#.  Make sure you have ``git``, ``make``, and ``dylan-compiler`` installed.

#.  Clone and build the ``dylan-tool`` project::

        $ git clone --recursive https://github.com/dylan-lang/dylan-tool.git
        $ cd dylan-tool
        $ make test
        $ make install

#.  Make sure that ``$DYLAN/bin`` is on your ``$PATH``. If you prefer not to set ``$DYLAN``,
    make sure that ``$HOME/dylan/bin`` is on your ``$PATH``.

You should now be able to run the Hello World example, below.


Hello World
===========

To make sure everything is working correctly, and to get a quick sense of
what's available, start by running the ``dylan help`` command.

To fully test your installation, try creating a temp workspace and updating
it. Here's an example using the ``logging`` library as an "active package" in
your workspace::

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

The ``dylan`` tool relies on :doc:`pacman`, the Dylan package manager (unrelated
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

Use ``dylan help``, ``dylan help <subcommand>``, or ``dylan <subcommand> --help`` to get help
on subcommands and options.

.. index::
   single: dylan new workspace subcommand
   single: subcommand; dylan new workspace

dylan new workspace
-------------------

The ``new workspace`` subcommand creates a new workspace directory and
initializes it with a ``workspace.json`` file. The workspace name is the only
required argument. ::

  $ dylan new workspace http
  $ cd http
  $ ls -l
  total 8
  -rw-r--r-- 1 you you   28 Dec 29 18:03 workspace.json

Options:
~~~~~~~~

``--directory``
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

.. index::
   single: dylan publish subcommand
   single: subcommand; dylan publish

dylan publish
-------------

The `publish` command adds a new release of a package to the package
catalog.

Synopsis: ``dylan publish <package-name>``

.. note:: For now, until a fully automated solution is implemented, it works by
          modifying the local copy of the catalog so that you can manually run
          the `pacman-catalog <https://github.com/dylan-lang/pacman-catalog>`_
          tests and submit a pull request. This eliminates a lot of
          possibilities for making mistakes while editing the catalog by hand.

This command may (as usual) be run from anywhere inside a workspace. Once
you're satisfied that you're ready to release a new version of your package
(tests pass, doc updated, etc.) follow these steps:

#.  Update the ``"version"`` attribute in `dylan-package.json` to be the new
    release's version, and commit the change.

#.  Make a new release on GitHub with a tag that matches the release version.
    For example, if the ``"version"`` attribute in `dylan-package.json` is
    ``"0.5.0"`` the GitHub release should be tagged ``v0.5.0``.

#.  Run ``dylan publish my-package``.  (If `pacman-catalog` isn't already an
    active package in your workspace the command will abort and give you
    instructions how to fix it.)

#.  Commit the changes to `pacman-catalog
    <https://github.com/dylan-lang/pacman-catalog>`_ and submit a pull request.
    The tests to verify the catalog will be run automatically by the GitHub CI.

#.  Once your PR has been merged, verify that the package is available in the
    catalog by running ``dylan install my-package@0.5.0``, substituting your
    new release name and version.

dylan update
------------

The ``update`` subcommand be be run from anywhere inside a workspace directory
and performs two actions:

#.  Installs all package dependencies, as specified in their
    ``dylan-package.json`` files.

#.  Updates the registry to have an entry for each library in the workspace
    packages or their dependencies.

    The ``registry`` directory is created at the same level as the ``workspace.json`` file
    and all registry files are written to a subdirectory named after the local platform.

    .. note::

       Registry files are only created if they apply to the architecture of the local
       machine. For example, on ``x86_64-linux`` LID files that specify ``Platforms: win32``
       will not cause a registry file to be generated.

Example:
~~~~~~~~

Create a workspace named ``http``, with one active package, ``http``, update
it, and build the test suite::

   $ dylan new workspace http
   $ cd http
   $ git clone --recursive https://github.com/dylan-lang/http
   $ dylan update
   $ dylan-compiler -build http-server-test-suite

Note that ``dylan-compiler`` must always be invoked in the workspace directory so
that it can find the ``registry`` directory. (This will be easier when the ``dylan
build`` command is implemented since it will ensure the compiler is invoked in
the right environment.)

.. index::
   single: dylan status subcommand
   single: subcommand; dylan status

dylan new library
-----------------

Generate the boilerplate for a new library, including:

* The library and module definition and initial source files
* A corresponding test suite library and initial source files
* A ``dylan-package.json`` file

Options:
~~~~~~~~

``--exe``
  Create an executable library. The primary difference is that with this
  flag a ``main`` function is generated and called.

Here's an example, which assumes you are already inside a Dylan workspace::

  $ dylan new library --exe killer-app
  $ dylan update     # generate registry files, assumes in a workspace
  $ dylan-compiler -build killer-app-test-suite
  $ _build/bin/killer-app-test-suite

You should edit the generated ``dylan-package.json`` file to set the repository
URL and description for your package, or if this library is part of an existing
package you can just delete ``dylan-package.json``.

dylan status
------------

Display the status of the current workspace, including all the active packages.

Options:
~~~~~~~~

``--directory``
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


.. _semantic version:  https://semver.org/spec/v2.0.0.html
