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

A workspace is described by a `workspace.conf` file containing a
single JSON object. Example:

    {
        "active": {
            "dylan-tool": {
                "url": "git@github.com:cgay/dylan-tool"
                "branch": "version-1.0.0"
            },
            "pacman": {
                "url": "git@github.com:cgay/pacman"
            },
            "uncommon-dylan": {
                "url": "git@github.com:cgay/uncommon-dylan"
            }
        }
    }

The "active" attribute describes the set of packages under active
development in this workspace. Assuming git as the source control
tool, these packages are ones that will be checked out into the
workspace directory rather than being searched for in the installed
packages directory.

After initial checkout the user may create a new branch or perform
whatever git operations are necessary.

Each key under "active" specifies a package that will be under active
development. These should match the name of an existing repository on
github. They are cloned into the workspace directory if a directory by
the same name doesn't already exist.

Each active package must have a "url" attribute with the git
repository URL to use for initial checkout. It may also have a
"branch" attribute to specify the git branch to select. The default is
"master".

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

