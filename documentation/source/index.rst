.. default-role:: samp
.. highlight:: json

******
pacman
******

`pacman` is the Dylan package manager library. It knows how to find packages in the
`catalog`_, install them, and how to resolve dependencies between them.

This documentation describes the package model and how versioned dependencies are
resolved. Users generally manage workspaces and packages via `the dylan command`_.

.. TODO: the above should link to the docs, not to top-level repo.

.. contents::
   :depth: 2

Packages
========

A package is just a unified blob of data that can be downloaded from the network and
unpacked into a directory. It may optionally have a `pkg.json` file in its top-level
directory to specify dependencies and other metadata.

.. note:: Currently `pacman` only supports `git` repositories downloaded via `git clone`,
          but it will soon support `.zip` and `.tar.gz` files via HTTPS.

Package Versions
================

Package versions are either `SemVer 2.0`_ versions or `git` branch names.

.. note:: Pre-release versions are not yet supported; just "MAJOR.MINOR.PATCH".

A package's version is determined by its `git` tags. If version "1.2.3" of package P is
requested there must be a `git` tag `v1.2.3` on P's `git` repository. (Non-`git` and even
non-VCS packages may be supported in the future.)

Package Dependencies and pkg.json
=================================

Package dependencies are specified in the `pkg.json` file, along with other package
metadata. Note that in the Beta version if this file does not exist `pacman` looks in
the `catalog`_ for package metadata.  Eventually this file will be required and there
will be an automated way to add a new release to the catalog, based on this file.

Let's look at the `pkg.json` file for `pacman` itself::

    {
        "name": "pacman",
        "deps": [
            "json@1.0",
            "logging@2.0",
            "regular-expressions@1.0",
            "testworks@2.0",
            "uncommon-dylan@0.2"
        ],
        "location": "https://github.com/dylan-lang/pacman"
    }

The "name" and "location" attributes should be fairly obvious. The "deps" attribute is a
list of package dependencies. Dependency specs can take the following forms:

=================   ==============================
Spec                Meaning
=================   ==============================
`pkg`               Same as `pkg@latest`.
`pkg@latest`        Use the latest numbered, non-pre-release version.
`pkg@1.2.3`         Use version 1.2.3 exactly.
`pkg@1.2.3-beta2`   Use version 1.2.3-beta2 exactly. (**Pre-release versions are
                    not yet supported.**)
`pkg@1.2`           Use the latest patch version of minor version 1.2.
`pkg@feature`       Use the `feature` branch instead of a tagged version.
                    Normally this should only be used during development.
=================   ==============================

The expectation is that when a package is released, its dependencies should be specified
precisely, at least `pkg@<major>.<minor>`, so that user builds will be
reproducible. `pkg@latest` and `pkg@feature` are primarily intended for use during
development.

Dependency Resolution
=====================

When `the dylan command`_ is asked to update a workspace it asks `pacman` to resolve the
dependencies specified in the `pkg.json` file (or the `catalog`_) and to install the
resolved versions of those packages. So how does `pacman` do the package resolution,
especially if there is a conflict?

The long answer is that `pacman` uses `minimal version selection`_ (MVS). To read more
than you ever wanted to know about this subject unless you're Russ Cox, check out
https://research.swtch.com/vgo. In particular, check out the `principles`_ post in that
series, for motivation. What follows is a very brief summary of minimal version
selection.

Unlike most traditional package systems, in which when you specify version 1.2 you are
really saying "give me the *latest* version that is at least 1.2", with MVS you are
saying "give me the *lowest* (i.e., minimal) version that is at least 1.2". Why would you
want this?  Isn't it a feature to get the latest *compatible* software when you build?
Well, in fact, a much better feature is to get a *repeatable build* each time. That is
what MVS provides.

Think about it. If the latest versions are preferred, then building your code at time `T`
may very well result in a different binary, with different bugs, than when you build your
code at time `T+1`. Your users will *always* build the code at a later time than you did.

Example
-------

Let's say you build an application that depends on (and you have tested with)
`strings@2.5` and `http@1.3`, and that `http@1.3` itself depends on `strings@2.4.2`.
Further, let's assume that there are three patch versions of `strings@2.5`:
`strings@2.5.0`, `strings@2.5.1`, and `strings@2.5.2`. Which version of `strings` should
`pacman` install?

The answer is `strings@2.5.0` because that is the minimum version that is compatible with
*both* `strings@2.5` and `strings@2.4.2` based on `SemVer 2.0`_ rules.

What if `http@1.3` instead depended on `strings@3.0.1`? In this case `pacman` would
signal an error because `strings@2.5` is not compatible with `strings@3.x.y` since they
have different major versions.

You could say that MVS uses the "maximum (compatible) minimum version".

Index and Search
================

* :ref:`genindex`
* :ref:`search`

.. _minimal version selection: https://research.swtch.com/vgo-mvs
.. _principles:                https://research.swtch.com/vgo-principles
.. _the dylan command: https://github.com/dylan-lang/dylan-tool.git
.. _catalog:    https://github.com/dylan-lang/pacman-catalog.git
.. _SemVer 2.0: https://semver.org/spec/v2.0.0.html
