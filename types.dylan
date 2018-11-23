Module: %pacman

// This enables the #string: prefix to "parse" raw string literals.
define function string-parser (s :: <string>) => (_ :: <string>) s end;

define constant $uncategorized = "Uncategorized";
define constant $pkg-dir-name = "pkg";

define constant $head-name = "head";
define constant $latest-name = "latest";

define constant <dep-vec> = limited(<vector>, of: <dep>);
define constant <pkg-vec> = limited(<vector>, of: <pkg>);

define class <package-error> (<simple-error>)
end;

define function package-error (msg :: <string>, #rest args)
  error(make(<package-error>, format-string: msg, format-arguments: args));
end;

// TODO: Windows
define constant $default-dylan-directory = "/opt/dylan";
define constant $dylan-dir-name = "dylan";
define constant $dylan-env-var = "DYLAN";

// The base directory for all things Dylan for a given user.
//   1. ${DYLAN}
//   2. ${HOME}/dylan or %APPDATA%\dylan
//   3. /opt/dylan or ??? on Windows
// TODO: Dylan implementations should export this.
define function dylan-directory
    () => (dir :: <directory-locator>)
  let dylan = os/getenv($dylan-env-var);
  if (dylan)
    as(<directory-locator>, dylan)
  else
    // TODO: use %APPDATA% on Windows
    let home = os/getenv("HOME");
    if (home)
      subdirectory-locator(as(<directory-locator>, home), $dylan-dir-name)
    else
      as(<directory-locator>, $default-dylan-directory)
    end
  end
end;

// <pkg> represents a specific version of a package.
define class <pkg> (<object>)
  constant slot name :: <string>, required-init-keyword: name:;
  constant slot version :: <version>, required-init-keyword: version:;
  constant slot deps :: <dep-vec> = as(<dep-vec>, #[]), init-keyword: deps:;
  constant slot entry :: false-or(<entry>) = #f, init-keyword: entry:;
  // Where the package can be downloaded from.
  constant slot location :: false-or(<string>) = #f, init-keyword: location:;
end;

define method initialize (pkg :: <pkg>, #key name) => ()
  next-method();
  validate-package-name(name);
end;

define method print-object (pkg :: <pkg>, stream :: <stream>) => ()
  format(stream, 
         if (*print-escape?*) "<pkg %s %s>" else "%s %s" end,
         pkg.name, pkg.version);
end;

// A package with the same name and version is guaranteed to have all
// other attributes the same.
define method \= (p1 :: <pkg>, p2 :: <pkg>) => (_ :: <bool>)
  istring=(p1.name, p2.name) & p1.version = p2.version
end;

define constant $pkg-name-regex = #regex:{^[A-Za-z][A-Za-z0-9.-]*$};

define function validate-package-name (name :: <string>) => ()
  re/search-strings($pkg-name-regex, name)
  | package-error("invalid package name: %=", name);
end;

// Convert to table for outputing as JSON. Only deps and location are
// needed because version and name are encoded higher up in the JSON
// object structure.
define method to-table (pkg :: <pkg>) => (t :: <istring-table>)
  table(<istring-table>,
        "deps" => map(dep-to-string, pkg.deps),
        "location" => pkg.location)
end;

define class <version> (<object>)
  constant slot major :: <int>, required-init-keyword: major:;
  constant slot minor :: <int>, required-init-keyword: minor:;
  constant slot patch :: <int>, required-init-keyword: patch:;
  // TODO: consider adding a tag slot for "alpha-1" or "rc.3". I think
  // it would not be part of the equality comparisons and would be
  // solely for display purposes but I'm not sure.
end;

define method print-object (v :: <version>, stream :: <stream>) => ()
  format(stream,
         if (*print-escape?*) "<version %s>" else "%s" end,
         version-to-string(v));
end;

// $latest refers to the latest numbered version of a package.
define class <latest> (<version>, <singleton-object>) end;
define constant $latest :: <latest> = make(<latest>, major: -1, minor: -1, patch: -1);

// $head refers to the bleeding edge devhead version, which has no number.
// Usually the "master" branch in git terms.
define class <head> (<version>, <singleton-object>) end;
define constant $head :: <head> = make(<head>, major: 0, minor: 0, patch: 0);

define function version-to-string (v :: <version>) => (_ :: <string>)
  select (v)
    $head     => $head-name;
    $latest   => $latest-name;
    otherwise => sprintf("%d.%d.%d", v.major, v.minor, v.patch)
  end
end;

define constant $version-regex = #regex:{^(\d+)\.(\d+)\.(\d+)$};

define function string-to-version
    (input :: <string>) => (_ :: <version>)
  select (input by istring=)
    $head-name   => $head;
    $latest-name => $latest;
    otherwise =>
      let (_, maj, min, pat) = re/search-strings($version-regex, input);
      maj | package-error("invalid version spec: %=", input);
      maj := string-to-integer(maj);
      min := string-to-integer(min);
      pat := string-to-integer(pat);
      if (maj < 0 | min < 0 | pat < 0 | (maj + min + pat = 0))
        package-error("invalid version spec: %=", input);
      end;
      make(<version>, major: maj, minor: min, patch: pat)
  end
end;

define method \= (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  v1.major == v2.major
  & v1.minor == v2.minor
  & v1.patch == v2.patch
end;

define method \< (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  case
    v1 = $head   => #f;
    v1 = $latest => v2 = $head;
    v2 = $head   => v1 ~= $head;
    v2 = $latest => (v1 ~= $head & v1 ~= $latest);
    otherwise =>
      v1.major < v2.major
        | (v1.major == v2.major
             & (v1.minor < v2.minor
                  | (v1.minor == v2.minor & v1.patch < v2.patch)))
  end
end;
  

// A dependency on a specific version of a package. To depend on a specific, single
// version of a package specify min-version = max-version.  If neither min- nor
// max-version is supplied then any version of the package is considered to fulfill
// the dependency.
define class <dep> (<object>)
  constant slot package-name :: <string>, required-init-keyword: package-name:;
  constant slot min-version :: false-or(<version>) = #f, init-keyword: min-version:;
  constant slot max-version :: false-or(<version>) = #f, init-keyword: max-version:;
end;

define method initialize (dep :: <dep>, #key package-name) => ()
  next-method();
  validate-package-name(package-name);
  let minv = dep.min-version;
  let maxv = dep.max-version;
  if (minv & maxv & ~(minv <= maxv))
    package-error("invalid dependency: %=", dep-to-string(dep));
  end;
end;

define method print-object (dep :: <dep>, stream :: <stream>) => ()
  format(stream,
         if (*print-escape?*) "<dep %s>" else "%s" end,
         dep-to-string(dep));
end;

define method \= (d1 :: <dep>, d2 :: <dep>) => (_ :: <bool>)
  istring=(d1.package-name, d2.package-name)
  & d1.min-version = d2.min-version
  & d1.max-version = d2.max-version
end;

// TODO: I like the dependency syntax/semantics used by Cargo. Will
//       probably switch to those, but it can wait because for now we
//       mostly can use 'head'. Might be more complex than necessary?
define function dep-to-string (dep :: <dep>) => (_ :: <string>)
  let name = dep.package-name;
  let minv = dep.min-version;
  let maxv = dep.max-version;
  case
    ~minv & ~maxv => concat(name, " *");
    ~minv         => concat(name, " <", version-to-string(maxv));
    ~maxv         => concat(name, " >", version-to-string(minv));
    minv = maxv   => concat(name, " ", version-to-string(minv));
    // bleh, this isn't right because it needs to indicate <= max version
    otherwise     => sprintf("%s %s-%s", name, version-to-string(minv), version-to-string(maxv));
  end
end;

// TODO: validate package names against this when packages are added.
// Start out with a restrictive naming scheme. Can expand later if needed.
// define constant $package-name-regex :: <regex> = #regex:{([a-zA-Z][a-zA-Z0-9-]*)};
define constant $dependency-regex :: <regex>
  = begin
      let rev = #string:"(\d+\.\d+\.\d+)";
      let range = concat(rev, "-", rev);
      let version-spec = concat(#string:"(head|\*|([<=>])?", rev, "|", range, ")");
      // groups: 1:name, 2:vspec, 3:[<=>], 4: v1, 5:v1, 6:v2
      let pattern = concat("^([A-Za-z][A-Za-z0-9-]*)(?: ", version-spec, ")?$");
      re/compile(pattern)
    end;

// Parse a dependency spec as generated by `dep-to-string`.
define function string-to-dep
    (input :: <string>) => (d :: <dep>)
  let (whole, name, vspec, binop, v1a, v1b, v2) = re/search-strings($dependency-regex, input);
  if (~whole)
    // TODO: add doc link explaining dependency syntax.
    package-error("Invalid dependency spec: %=", input);
  end;
  let (minv, maxv) = #f;
  case
    vspec = "*" => #f;
    vspec = $head-name => #f;
    v2 =>
      minv := v1b;
      maxv := v2;
    otherwise =>
      select (binop by \=)
        "<"     => maxv := v1a;
        "=", #f => minv := v1a; maxv := v1a;
        ">"     => minv := v1a;
      end;
  end;
  make(<dep>,
       package-name: name,
       min-version: minv & string-to-version(minv),
       max-version: maxv & string-to-version(maxv))
end;

define function satisfies?
    (dep :: <dep>, version :: <version>) => (_ :: <bool>)
  let (minv, maxv) = values(dep.min-version, dep.max-version);
  (~minv & ~maxv)               // any version will do
    | (~maxv & version >= minv)
    | (~minv & version <= maxv)
    | (minv & maxv & version >= minv & version <= maxv)
end;


// The catalog knows what packages (and versions thereof) exist.
define sealed class <catalog> (<object>)
  // package name -> <entry>
  constant slot entries :: <istring-table>, required-init-keyword: entries:;
end;

// Something that knows how to grab a package off the net and unpack
// it into a directory.
define abstract class <transport> (<object>)
end;

// Install git packages.
define class <git-transport> (<transport>)
  constant slot branch :: <string> = "master", init-keyword: branch:;
end;

// TODO: mercurial, tarballs, ...

// The package manager will never modify anything outside this
// directory unless explicitly requested (e.g., via a directory passed
// to download).
define function package-manager-directory
    () => (dir :: <directory-locator>)
  subdirectory-locator(dylan-directory(), $pkg-dir-name)
end;

// Display a message on stdout. Abstracted here so we can easily change all
// output, or log it or whatever.
define function message
    (pattern :: <string>, #rest args) => ()
  apply(printf, pattern, args)
end;

define function read-package-file (file :: <file-locator>) => (pkg :: false-or(<pkg>))
  message("Reading package file %s\n", file);
  block ()
    with-open-file (stream = file)
      let json = json/parse(stream, table-class: <istring-table>, strict?: #f);
      let name = element(json, "name", default: #f)
        | package-error("Invalid package file %s: expected a 'name' field.", file);
      let deps = element(json, "deps", default: #f)
        | package-error("Invalid package file %s: expected a 'deps' field.", file);
      make(<pkg>,
           name: name,
           deps: map-as(<dep-vec>, string-to-dep, deps),
           version: element(json, "version", default: $latest),
           location: element(json, "location", default: #f))
    end
  exception (e :: <file-does-not-exist-error>)
    #f
  end
end;

