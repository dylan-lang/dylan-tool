Module: package-manager
Synopsis: Package manager API

///
/// Packages
///

// Return all of pkg's versions as a sequence. The sequence is sorted
// from oldest version to latest version.
define sealed generic all-versions
    (pkg :: <package>) => (versions :: <sequence>);

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
    (cat :: <catalog>, pkg :: <package>) => ();

// Add a new version to an existing package or signal <package-error>,
// for example if the given version already exists, or does not have
// the highest version number.
define sealed generic add-version
    (cat :: <catalog>, pkg :: <package>, ver :: <version>) => ();

// Remove a package (all versions) from the catalog if it is
// present. Signal <package-error> if the package was present and
// couldn't be removed, for example if there was a problem persisting
// the modified catalog.
define sealed generic remove-package
    (cat :: <catalog>, pkg-name :: <string>) => (removed? :: <boolean>);

// TODO:
//   * verify-package[-version] ?

// TODO: or define forward-iteration-protocol(<catalog>)
define sealed generic all-packages
    (cat :: <catalog>) => (pkgs :: <sequence>);

// Find a package in the catalog that has the given name. Package
// names are always compared ignoring case.
define sealed generic find-package
    (cat :: <catalog>, pkg-name :: <string>) => (pkg :: false-or(<package>));

///
/// Installation
///

// Download package's source into dest-dir or signal <package-error>,
// for example on a network failure.  This is distinct from installing
// the package.
define sealed generic download-version
    (pkg :: <package>, ver :: <version>, dest-dir :: <directory-locator>) => ();

// Download and install the given version of pkg into the standard
// location and update the LATEST pointer if version is the latest
// version. (What else?)
define sealed generic install-version
    (pkg :: <package>, ver :: <version>) => ();


///
/// Versions
///

// Return version's dependencies, a sequence of other package
// versions.  If transitive? is true, expand transitive dependencies
// and remove duplicates.
define sealed generic transitive-dependencies
    (version :: <version>) => (deps :: <dependency-list>);
