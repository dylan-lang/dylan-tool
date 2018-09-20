Module: package-manager
Synopsis: Package manager API

///
/// Packages
///

// Return all of pkg's versions as a sequence. The sequence is sorted
// from oldest version to latest version.
define sealed generic all-versions
    (pkg :: <pkg>) => (versions :: <pkg-vec>);

// Return pkg's dependencies, a sequence of other package
// versions, in the order they appear in the package definition, with
// duplicates removed.
define sealed generic transitive-dependencies
    (pkg :: <pkg>) => (deps :: <dep-vec>);

///
/// Catalog
///

// Load the catalog from storage. If there is no catalog in the given
// storage location an empty catalog is returned.
define open generic load-catalog
    (store :: <storage>) => (cat :: <catalog>);

// Store a catalog in a format appropriate for the given storage.
define open generic store-catalog
    (catalog :: <catalog>, store :: <storage>);

// Add a new package to the catalog or signal <package-error>, for
// example if there was a problem persisting the modified catalog or
// if the package was already present.
// TODO: should the package be allowed to have any versions?
define sealed generic add-package
    (cat :: <catalog>, pkg :: <pkg>) => ();

// Remove a package (all versions) from the catalog if it is
// present. Signal <package-error> if the package was present and
// couldn't be removed, for example if there was a problem persisting
// the modified catalog.
define sealed generic remove-package
    (cat :: <catalog>, pkg-name :: <str>) => (removed? :: <boolean>);

// TODO:
//   * verify-package[-version] ?

// Return all packages in the catalog as a sequence.
define sealed generic all-packages
    (cat :: <catalog>) => (pkgs :: <sequence>);

// Find a package in the catalog that has the given name. Package
// names are always compared ignoring case.
define sealed generic find-package
    (cat :: <catalog>, pkg-name :: <str>, ver :: <version>) => (pkg :: false-or(<pkg>));

///
/// Installation
///

// Download package source into dest-dir or signal <package-error>,
// for example on a network failure.  This is distinct from installing
// the package.
define sealed generic download-package
    (pkg-name :: <str>, ver :: <version>, dest-dir :: <directory-locator>) => (p :: <pkg>);

// Download and install the given version of pkg-name into the
// standard location and update the LATEST pointer if version is the
// latest version.
define sealed generic install-package
    (pkg-name :: <str>, v :: <version>) => (p :: <pkg>);
