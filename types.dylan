Module: package-manager

// Package names are not case-sensitive.
define constant <package-table> = <case-insensitive-string-table>;

// These use "list" in the generic sense of the word.
define constant <string-list> = limited(<vector>, of: <string>);
define constant <version-list> = limited(<vector>, of: <version>);
define constant <dependency-list> = limited(<vector>, of: <dependency>);
define constant <package-list> = limited(<vector>, of: <package>);


// The thing that manages packages. Basically a place to put state
// rather than using global variables.
define class <manager> (<object>)
  slot packages :: <package-table> = make(<package-table>);
end class <manager>;


define class <package-error> (<simple-error>)
end;


// A package knows about a package as a whole, but info that can
// change when a new version is added to the catalog is stored in the
// <version> class.
define abstract class <package> (<object>)
  constant slot name :: <string>, required-init-keyword: name:;
  constant slot synopsis :: <string>, required-init-keyword: synopsis:;
  constant slot description :: <string>, required-init-keyword: description:;
  constant slot versions :: <version-list>, required-init-keyword: versions:;
  constant slot contact :: <string>, required-init-keyword: contact:;
  constant slot license :: <string>, required-init-keyword: license:;

  // Optional slots
  constant slot keywords :: false-or(<string-list>) = #f, init-keyword: keywords:;
  constant slot category :: false-or(<string>) = #f, init-keyword: category:;
end class <package>;


// A simple reference to a specific version of a package.
define class <dependency> (<object>)
  constant slot package-name :: <string>, required-init-keyword: name:;
  constant slot version :: <string>, required-init-keyword: version:;
end class <dependency>;


// Metadata for a specific version of a package. Anything that can
// change when a new version of the package is released (which is most
// things).
define class <version> (<object>)
  // Back pointer to the package containing this version.
  slot package :: <package>, init-keyword: package:;

  constant slot major :: <integer>, required-init-keyword: major:;
  constant slot minor :: <integer>, required-init-keyword: minor:;
  constant slot patch :: <integer>, required-init-keyword: patch:;
  // Might consider adding a tag slot for "alpha-1" or "rc.3". I think
  // it would not be part of the equality comparisons and would be
  // solely for display purposes but I'm not sure.

  constant slot dependencies :: <dependency-list>, required-init-keyword: dependencies:;

  // Some sort of URL that identifies where the package can be
  // downloaded from. For example a git repo or URL pointing to a
  // tarball. (Details TBD. Could be type <url>?)
  constant slot location :: <string>, required-init-keyword: location:;
end class <version>;

/*
define method \= (v1 :: <version>, v2 :: <version>) => (equal? :: <boolean>)
  v1.major == v2.major
  & v1.minor == v2.minor
  & v1.patch == v2.patch
end method;

define method \< (v1 :: <version>, v2 :: <version>) => (less? :: <boolean>)
  v1.major < v2.major |
  (v1.major == v2.major &
     (v1.minor < v2.minor |
        (v1.minor == v2.minor & v1.patch < v2.patch)))
end method;

// > is automatically defined in terms of = and <.
*/

// The catalog knows what packages (and versions thereof) exist.
define sealed class <catalog> (<object>)
  // Maps package names to <package>s.
  constant slot packages :: <package-table> = make(<package-table>);
end class <catalog>;

// A place to store catalog data.
define class <storage> (<object>)
end class <storage>;

