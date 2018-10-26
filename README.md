# Dylan Tool

The "dylan" tool simplifies the creation of Dylan workspaces and
package management by using a config file to specify packages that are
under active development and managing a single "registry" for the user
in what should (hopefully) become a standard development setup for
Dylan hackers. This should eliminate the need to manage registries by
hand and the need to use git submodules to track dependencies.

For the initial release of this tool, the user must create a workspace
file by hand and then run `dylan update` to initialize the workspace
and again whenever the file changes.

The tool clones the "active" git repositories into the workspace
directory if they don't already exist, installs package dependencies,
and creates registry files as needed.

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
match the name of an existing package in the Catalog, and if a
subdirectory by this name doesn't exist in the workspace file's
directory, dylan-tool will do the initial checkout for you. If you're
creating a new package then you'll need to create the directory
yourself, create a pkg.json file inside it, and then run `dylan-tool
update` and it will fetch the package's dependencies for you.

## The Registry

Open Dylan uses "registries" to locate library sources. Setting up a
development workspace historically involved a lot of manual git
cloning and creating registry files for each used library.

Obviously just cloning git repositories into the workspace directory
isn't all that helpful and can be done by hand if you prefer. (If the
directory already exists the tool won't attempt to do a "git clone"
operation.)  Instead, the main purpose of specifying active packages
is so that the "dylan" tool can create the registry files for you
accurately.  The registry points to the active packages in the
workspace directory but points to the installation directory
(`${DYLAN}/pkg/...`) for all other dependencies. 

## TODO List

This only lists important items. There are TODOs in the code as well,
but mostly for smaller or less important items. Some of the items on
this list are more for pacman than dylan-tool.

### For 1.0.0

Version 1.0.0 will primarily work with packages at HEAD since that's
the way everyone currently expects to work on Dylan.  Better support
for numbered versions can come later.

* Workspace file should only need to be a list of packages to work
  on and their deps should be looked up in the catalog if not listed
  in the workspace file. Putting deps in the workspace file is
  mainly useful for NEW projects.

* Deps of the form "pkg/*" should just be "pkg", meaning the latest
  version.

* Auto-create the workspace file from list of package names. For
  example, "dylan-tool new pkg1 pkg2".

* Auto-download the catalog from github rather than expecting it to be
  local.

### After 1.0.0

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
