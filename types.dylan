Module: %pacman

// Trying these on for size.
define constant <any> = <object>;
define constant <bool> = <boolean>;
define constant <int> = <integer>;
define constant <seq> = <sequence>;
define constant <str> = <string>;
define constant <str-map> = <string-table>;
define constant <istr-map> = <case-insensitive-string-table>;

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
  constant slot packages :: <pkg-vec>, required-init-keyword: packages:;

  // Who to contact with questions about this package.
  constant slot contact :: <str>, required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot license-type :: <str>, required-init-keyword: license-type:;

  constant slot keywords :: false-or(<seq>) = #f, init-keyword: keywords:;
  constant slot category :: false-or(<str>) = #f, init-keyword: category:;
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
    (v :: <version>) => (_ :: <str>)
  format-to-string("%d.%d.%d", v.major, v.minor, v.patch)
end;

define constant $version-regex :: <regex> = compile-regex("(\\d+)\\.(\\d+)\\.(\\d+)");

define function string-to-version
    (input :: <str>) => (_ :: <version>)
  let (_, maj, min, pat) = regex-search-strings($version-regex, input);
  make(<version>,
       major: string-to-integer(maj),
       minor: string-to-integer(min),
       patch: string-to-integer(pat))
end;

define class <latest> (<version>, <singleton-object>)
end;

define constant $latest :: <latest> = make(<latest>, major: -1, minor: -1, patch: -1);

define method \= (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  v1.major == v2.major
  & v1.minor == v2.minor
  & v1.patch == v2.patch
end;

define method \< (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  v1.major < v2.major
  | (v1.major == v2.major
       & (v1.minor < v2.minor
            | (v1.minor == v2.minor & v1.patch < v2.patch)))
end;
  

// A dependency on a specific version of a package.
define class <dep> (<any>)
  constant slot package-name :: <str>, required-init-keyword: name:;
  constant slot version :: <version>, required-init-keyword: version:;
end;

define function dep-to-string (dep :: <dep>) => (_ :: <str>)
  format-to-string("%s/%s", dep.package-name, version-to-string(dep.version))
end;

// TODO: validate package names against this when packages are added.
// Start out with a restrictive naming scheme. Can expand later if needed.
define constant $package-name-regex :: <regex> = compile-regex("([a-zA-Z][a-zA-Z0-9-]*)");
define constant $dependency-regex :: <regex>
  = compile-regex(concatenate(regex-pattern($package-name-regex),
                              "/(", regex-pattern($version-regex), ")"));

// Parse a dependency spec in the form pkg-name/m.n.p.
define function string-to-dep
    (input :: <str>) => (d :: <dep>)
  let (_, name, version) = regex-search-strings($dependency-regex, input);
  if (~name)
    catalog-error("Invalid dependency spec, %=, should be in the form pkg/1.2.3", input)
  end;
  make(<dep>, name: name, version: string-to-version(version))
end;


// Metadata for a specific version of a package. Anything that can
// change when a new version of the package is released.
define class <pkg> (<any>)
  slot group :: <pkg-group>;    // back-pointer filled in after init.
  constant slot version :: <version>, required-init-keyword: version:;
  constant slot dependencies :: <dep-vec>, required-init-keyword: dependencies:;

  // Identifies where the package can be downloaded from. For example
  // a git repo or URL pointing to a tarball. (Details TBD. Could be
  // type <url>?)
  constant slot source-url :: <str>, required-init-keyword: source-url:;
end;


// The catalog knows what packages (and versions thereof) exist.
define sealed class <catalog> (<any>)
  // Maps package names to <pkg-group>s.
  constant slot package-groups :: <istr-map>, required-init-keyword: package-groups:;
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
