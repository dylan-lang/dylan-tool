Module: %pacman
Synopsis: Package manager API

///
/// Catalog
///

// Add a new package to the catalog or signal <package-error>, for
// example if there was a problem persisting the modified catalog, the
// package was already present, or one of the package's dependencies
// wasn't in the catalog.
define sealed generic add-package
    (cat :: <catalog>, pkg :: <pkg>) => ();

// Remove a package (all versions) from the catalog if it is
// present. Signal <package-error> if the package was present and
// couldn't be removed, for example if there was a problem persisting
// the modified catalog.
define sealed generic remove-package
    (cat :: <catalog>, pkg-name :: <str>) => (removed? :: <bool>);

// TODO:
//   * verify-package[-version] ?

// Return all packages in the catalog as a sequence.
define sealed generic all-packages
    (cat :: <catalog>) => (pkgs :: <seq>);

// Find a package in the default catalog having the given `name` and
// `version`. Package names are always compared ignoring case.  The
// special version `$latest` finds the latest version of a package.
// Signals `<package-error>` if not found.
define sealed generic find-package
    (pkg-name :: <str>, version :: <any>) => (pkg :: <pkg>);

///
/// Installation
///

// Generally call these functions with the result of find-package(name, version).

// Download package source into `dir` or signal <package-error> (for
// example due to a network or file-system error). Dependencies are
// not downloaded.
define sealed generic download-package
    (pkg :: <pkg>, dir :: <directory-locator>) => ();

// Download and install `pkg` into the standard location and update
// the LATEST pointer if it's the latest version of the package. If
// `force?` is true the existing package is removed, if present, and
// the package is re-installed.  If `deps?` is true , also install
// dependencies recursively. The `force?` argument applies to
// dependent installations also. If `skip` is provided it must be a
// list of package names (strings) to skip while installing
// dependencies.
define sealed generic install-package
    (pkg :: <pkg>, #key force?, deps?) => ();
