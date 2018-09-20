Module: package-manager

// This file might better be called load-me-first.dylan.

// Trying these on for size.
define constant <int> = <integer>;
define constant <any> = <object>;
define constant <str> = <string>;
define constant <str-map> = <string-table>;
define constant <istr-map> = <case-insensitive-string-table>;

define constant <str-vec> = limited(<vector>, of: <str>);
define constant <dep-vec> = limited(<vector>, of: <dep>);
define constant <pkg-vec> = limited(<vector>, of: <pkg>);

define class <package-error> (<simple-error>)
end;

define function package-error
    (msg :: <str>, #rest args)
  error(make(<package-error>, format-string: msg, format-arguments: args));
end;

// The name of the Dylan environment variable.
define constant $dylan :: <str> = "DYLAN";

define constant $default-dylan-directory :: <str> = "/opt/dylan";

// The base directory for all things Dylan for a given user.
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
end;

// A <pkg-group> knows about a package as a whole, but info
// that can change when a new version is added to the catalog is
// stored in the <pkg> class.
define class <pkg-group> (<any>)
  constant slot name :: <str>, required-init-keyword: name:;
  constant slot synopsis :: <str>, required-init-keyword: synopsis:;
  constant slot description :: <str>, required-init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot contact :: <str>, required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot license-type :: <str>, required-init-keyword: license-type:;

  constant slot keywords :: false-or(<str-vec>) = #f, init-keyword: keywords:;
  constant slot category :: false-or(<str>) = #f, init-keyword: category:;
end;


// A dependency on a specific version of a package.
define class <dep> (<any>)
  constant slot package-name :: <str>, required-init-keyword: name:;
  constant slot version :: <version>, required-init-keyword: version:;
end;

// Metadata for a specific version of a package. Anything that can
// change when a new version of the package is released.
define class <pkg> (<any>)
  constant slot group :: <pkg-group>, required-init-keyword: group:;
  constant slot version :: <version>, required-init-keyword: version:;
  constant slot dependencies :: <dep-vec>, required-init-keyword: dependencies:;

  // Identifies where the package can be downloaded from. For example
  // a git repo or URL pointing to a tarball. (Details TBD. Could be
  // type <url>?)
  constant slot source-url :: <str>, required-init-keyword: source-url:;
end;

define class <version> (<any>)
  constant slot major :: <int>, required-init-keyword: major:;
  constant slot minor :: <int>, required-init-keyword: minor:;
  constant slot patch :: <int>, required-init-keyword: patch:;
  // TODO: consider adding a tag slot for "alpha-1" or "rc.3". I think
  // it would not be part of the equality comparisons and would be
  // solely for display purposes but I'm not sure.
end;

define function version-to-string
    (ver :: <version>) => (v :: <str>)
  format-to-string("%d.%d.%d", ver.major, ver.minor, ver,patch)
end;

// TODO: subclass uncommon-dylan:<singleton-object>. Don't want to deal with
// updating the registry and so on right now....
define class <latest> (<version>)
end;

define method make (class == <latest>, #key) => (v :: <latest>)
  next-method(class, major: -1, minor: -1, patch: -1)
end;

define constant $latest :: <latest> = make(<latest>);


// The catalog knows what packages (and versions thereof) exist.
define sealed class <catalog> (<any>)
  // Maps package names to <pkg>s.
  constant slot packages :: <istr-map> = make(<istr-map>);
end;

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

// Display a message on stdout. Abstracted here so we can easily change all
// output, or log it or whatever.
define function message
    (fmt :: <str>, #rest args) => ()
  apply(format-out, fmt, args)
end;
