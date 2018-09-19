Module: package-manager

// TODO: probably rename this file to package-manager.dylan or core.dylan or something.

// Trying these on for size.
define constant <int> = <integer>;
define constant <any> = <object>;
define constant <str> = <string>;
define constant <str-map> = <string-table>;
// Package names are not case-sensitive.
define constant <pkg-map> = <case-insensitive-string-table>;

// These use "list" in the generic sense of the word.
define constant <str-list> = limited(<vector>, of: <str>);
define constant <dep-list> = limited(<vector>, of: <dep>);
define constant <pkg-list> = limited(<vector>, of: <pkg>);

define class <pkg-error> (<simple-error>)
end;

// The name of the Dylan environment variable.
define constant $dylan :: <str> = "DYLAN";

define constant $default-dylan-directory :: <str> = "/opt/dylan";

// The Dylan package directory is chosen in this order:
//   1. ${DYLAN}
//   2. ${HOME}/dylan or %APPDATA%\dylan
//   3. /opt/dylan
// TODO: Dylan implementations should export this.
define function dylan-directory
    () => (dir :: <directory-locator>)
  let dylan = environment-variable($dylan);
  if (dylan)
    as(<directory-locator>, dylan)
  else
    // TODO: use %APPDATA% on Windows
    let home = environment-variable("HOME");
    if (home)
      subdirectory-locator(as(<directory-locator>, home), "dylan")
    else
      as(<directory-locator>, $default-dylan-directory)
    end
  end
end function dylan-directory;

// A <package-descriptor> knows about a package as a whole, but info
// that can change when a new version is added to the catalog is
// stored in the <pkg> class.
define abstract class <package-descriptor> (<any>)
  constant slot name :: <str>, required-init-keyword: name:;
  constant slot synopsis :: <str>, required-init-keyword: synopsis:;
  constant slot description :: <str>, required-init-keyword: description:;
  constant slot packages :: <pkg-list>, required-init-keyword: package-versions:;

  // Who to contact with questions about this package.
  constant slot contact :: <str>, required-init-keyword: contact:;

  // License type for this package. Should this be in <package>
  // instead because it could change for a new version of the package?
  constant slot license-type :: <str>, required-init-keyword: license-type:;

  // Optional slots
  constant slot keywords :: false-or(<str-list>) = #f, init-keyword: keywords:;
  constant slot category :: false-or(<str>) = #f, init-keyword: category:;
end class <package-descriptor>;


// A simple reference to a specific version of a package.
define class <dep> (<any>)
  constant slot package-name :: <str>, required-init-keyword: name:;
  constant slot version :: <version>, required-init-keyword: version:;
end class <dep>;


// Metadata for a specific version of a package. Anything that can
// change when a new version of the package is released.
define class <pkg> (<any>)
  constant slot descriptor :: <package-descriptor>, required-init-keyword: descriptor:;
  constant slot version :: <version>, required-init-keyword: version:;
  constant slot dependencies :: <dep-list>, required-init-keyword: dependencies:;

  // Identifies where the package can be downloaded from. For example
  // a git repo or URL pointing to a tarball. (Details TBD. Could be
  // type <url>?)
  constant slot source-url :: <str>, required-init-keyword: source-url:;
end class <pkg>;

define class <version> (<any>)
  constant slot major :: <int>, required-init-keyword: major:;
  constant slot minor :: <int>, required-init-keyword: minor:;
  constant slot patch :: <int>, required-init-keyword: patch:;
  // Might consider adding a tag slot for "alpha-1" or "rc.3". I think
  // it would not be part of the equality comparisons and would be
  // solely for display purposes but I'm not sure.
end class <version>;

// TODO: subclass uncommon-dylan:<singleton-object>. Don't want to deal with
// updating the registry and so on right now....
define class <latest> (<version>) end;

define method make (class == <latest>, #key)
  next-method(class, major: -1, minor: -1, patch: -1)
end;

define constant $latest :: <latest> = make(<latest>);


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
define sealed class <catalog> (<any>)
  // Maps package names to <pkg>s.
  constant slot packages :: <str-map> = make(<str-map>);
end class <catalog>;

// A place to store catalog data.
define abstract class <storage> (<any>)
end;

// Something that knows how to grab a package off the net and unpack
// it into a directory.
define abstract class <transport> (<any>)
end;

// Install git packages.
define class <git-transport> (<transport>)
end;

// TODO: mercurial, tarballs, ...

// Root of all things package managerish.
define function package-manager-directory
    () => (dir :: <directory-locator>)
  subdirectory-locator(dylan-directory(), "pkg")
end;
