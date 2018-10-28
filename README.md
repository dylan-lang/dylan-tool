# Dylan Tool

The "dylan" tool simplifies the creation of Dylan workspaces and
package management by using a config file to specify packages that are
under active development and managing a single "registry" for the user
in what should (hopefully) become a standard development setup for
Dylan hackers. This should eliminate the need to manage registries by
hand and the need to use git submodules to track dependencies.

## Quick Start

1.  Make sure the `DYLAN` environment variable is set to wherever you
    do your Dylan hacking. For example:
   
        $ export DYLAN=${HOME}/dylan
   
    Dylan packages, including the
    [pacman-catalog](https://github.com/cgay/pacman-catalog) package
    which describes where to find other packages, will be installed
    under `${DYLAN}/pkg/`.
   
1.  Clone and build the `dylan-tool` project:

        $ git clone https://github.com/cgay/dylan-tool
        $ cd dylan-tool
        $ dylan-compiler -build dylan-tool.lid
        $ cp _build/bin/dylan-tool <somewhere-on-your-PATH>
      
1.  Create a new workspace. For example if you wanted to work on the
    http code you might want to have both 'http' and 'uri' as active
    packages:

        $ dylan-tool new web-stuff http uri

1.  Run the 'update' command to install package dependencies, download
    the active packages (http and uri in the example above), and create
    a registry with everything you need:
   
        $ cd web-stuff
        $ dylan-tool update

1.  Build your code:

        $ dylan-compiler -build http-server-example

If you want to create a new package, rather than doing development on
one that already exists, you must manually add it to the
`workspace.json` file and then run `dylan-tool update`. These are the
steps:

1.  Create a new directory for your package in the workspace directory.
1.  Create a `pkg.json` file that lists your package dependencies
    (deps). It should be straight-forward to copy from one in an
    existing package.
1.  Add the package name to the "active" list in the `workspace.json`
    file.
1.  Run `dylan-tool update` to install the deps and update the registry.

You may run `dylan-tool` commands from anywhere inside the workspace
directory tree; it will search up to find the "workspace.json" file.
In general you should build the code in the top-level workspace
directory so that all the active packages are built into the same
"_build" directory and so that `dylan-compiler` can find the
auto-generated "registry" directory.

## The Workspace File

A workspace is described by a `workspace.json` file containing a
single JSON object. Example:

    {
        "active": {
            "dylan-tool": {},
            "pacman": {},
            "uncommon-dylan": {}
        }
    }

(Note: There are currently no options so each package name simply maps
to an empty dictionary: `{}`.)

The "active" attribute describes the set of packages under active
development in this workspace. Assuming git as the source control
tool, these packages are ones that will be checked out into the
workspace directory rather than being searched for in the installed
packages directory.

After initial checkout the user may create a new branch or perform
whatever git operations are necessary.

Each key under "active" specifies a package that will be under active
development. If you're working on existing packages then these should
match the name of an existing package in the
[Catalog](https://github.com/cgay/pacman-catalog), and if a
subdirectory by this name doesn't exist in the workspace file's
directory, dylan-tool will do the initial checkout for you. If you're
creating a new package then you'll need to create the directory
yourself, create a pkg.json file inside it, and then run `dylan-tool
update` and it will fetch the package's dependencies for you.

## The Registry

Open Dylan uses "registries" to locate library sources. Setting up a
development workspace historically involved a lot of manual git
cloning and creating registry files for each used library.

The main purpose of specifying active packages is so that `dylan-tool`
can checkout those packages into the workspace directory and create
the registry files for you accurately.  The registry points to the
workspace directory for active package libries but points to the
installation directory, `${DYLAN}/pkg/...`, for all other
dependencies.

`dylan-tool` scans each active package for LID files and writes a
registry file for each one.

**Note:** If you use the same workspace directory on multiple
platforms (e.g., a network mounted directory or shared by a virtual
machine) you will need to run `dylan-tool update` on **both**
platforms so that the correct platform-specific registry entries are
created. `dylan-tool` makes no attempt to figure out which packages
are "generic" and which are platform-specific, so it always writes
platform-specific registry files.

## TODO List

This only lists important items. There are TODOs in the code as well,
but mostly for smaller or less important items. Some of the items on
this list are more for pacman than dylan-tool.

### For 0.1.0

Version 1.0.0 will primarily work with packages at HEAD since that's
the way everyone currently expects to work on Dylan.  Better support
for numbered versions can come later.

* Auto-download the catalog from github rather than expecting it to be
  local.

* Put all non-opendylan packages in the Catalog at version "head".

### After 0.1.0

* Separate the dylan-tool command and the workspace library so that
  the latter can be re-used by deft. (Perhaps put the dylan-tool
  command-line in the tests/ subdirectory so it can be used as a
  manual test, if I decide deft is the way to go.)

* Integrate pacman and workspace tool into Deft.

* Think about whether and how it makes sense to integrate knowledge of
  packages and versioned dependencies into Open Dylan itself.

* Remove the assumption that git (and specifically github) is where
  all packages reside. Support tarballs and/or zip files.

* Improve version dependency specs. Can get inspiration from Cargo
  here.
