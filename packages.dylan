Module: %pacman

define constant $head-name = "head";
define constant $latest-name = "latest";

define constant <dep-vector> = limited(<vector>, of: <dep>);

define class <package-error> (<simple-error>)
end class;

define function package-error (msg :: <string>, #rest args)
  error(make(<package-error>, format-string: msg, format-arguments: args));
end function;

// Represents a specific release of a package. Anything that might change for
// each release belongs here and anything that remains constant across all
// releases belongs in <package>.
define class <release> (<object>)
  constant slot release-version :: <version>,
    required-init-keyword: version:;
  constant slot release-deps :: <dep-vector> = as(<dep-vector>, #[]),
    required-init-keyword: deps:;
  // Back pointer to package containing this release.
  constant slot release-package :: false-or(<package>) = #f,
    required-init-keyword: package:;
  // Where the package can be downloaded from.
  constant slot release-location :: false-or(<string>) = #f,
    required-init-keyword: location:;
end class;

define method print-object
    (release :: <release>, stream :: <stream>) => ()
  printing-object (release, stream)
    format(stream, "%s %s", release.package-name, release.release-version);
  end;
end method;

// A package with the same name and version is guaranteed to have all
// other attributes the same.
//
// TODO: document why this method was necessary because I sure don't remember.
define method \=
    (rel1 :: <release>, rel2 :: <release>) => (_ :: <bool>)
  istring=(rel1.package-name, rel2.package-name)
    & rel1.release-version = rel2.release-version
end method;

define constant $pkg-name-regex = #:regex:{^[A-Za-z][A-Za-z0-9.-]*$};

define function validate-package-name
    (name :: <string>) => ()
  re/search-strings($pkg-name-regex, name)
    | package-error("invalid package name: %=", name);
end function;

// Convert to table for outputing as JSON.
define method to-table
    (release :: <release>) => (t :: <istring-table>)
  tabling(<istring-table>,
          // Name and version are encoded higher up in the JSON object
          // structure.
          "deps" => map(dep-to-string, release.release-deps),
          "location" => release.release-location)
end method;

define class <version> (<object>)
  constant slot version-major :: <int>, required-init-keyword: major:;
  constant slot version-minor :: <int>, required-init-keyword: minor:;
  constant slot version-patch :: <int>, required-init-keyword: patch:;
  // TODO: consider adding a tag slot for "alpha-1" or "rc.3". I think
  // it would not be part of the equality comparisons and would be
  // solely for display purposes but I'm not sure.
end class;

define method print-object
    (v :: <version>, stream :: <stream>) => ()
  printing-object (v, stream)
    write(stream, version-to-string(v));
  end;
end method;

// $latest refers to the latest numbered version of a package.
define class <latest> (<version>, <singleton-object>) end;
define constant $latest :: <latest> = make(<latest>, major: -1, minor: -1, patch: -1);

// $head refers to the bleeding edge devhead version, which has no number.
// Usually the head of the "master" branch in git terms.
define class <head> (<version>, <singleton-object>) end;
define constant $head :: <head> = make(<head>, major: 0, minor: 0, patch: 0);

define function version-to-string (v :: <version>) => (_ :: <string>)
  select (v)
    $head     => $head-name;
    $latest   => $latest-name;
    otherwise => sprintf("%d.%d.%d", v.version-major, v.version-minor, v.version-patch)
  end
end function;

define constant $version-regex = #:regex:{^(\d+)\.(\d+)\.(\d+)$};

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
end function;

define method \=
    (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  v1.version-major == v2.version-major
    & v1.version-minor == v2.version-minor
    & v1.version-patch == v2.version-patch
end method;

define method \<
    (v1 :: <version>, v2 :: <version>) => (_ :: <bool>)
  case
    v1 = $head   => #f;
    v1 = $latest => v2 = $head;
    v2 = $head   => v1 ~= $head;
    v2 = $latest => (v1 ~= $head & v1 ~= $latest);
    otherwise =>
      v1.version-major < v2.version-major
        | (v1.version-major == v2.version-major
             & (v1.version-minor < v2.version-minor
                  | (v1.version-minor == v2.version-minor
                       & v1.version-patch < v2.version-patch)))
  end
end method;


// A dependency on a specific version of a package. To depend on a specific, single
// version of a package specify min-version = max-version.  If neither min- nor
// max-version is supplied then any version of the package is considered to fulfill
// the dependency.
define class <dep> (<object>)
  constant slot package-name :: <string>, required-init-keyword: package-name:;
  constant slot min-version :: false-or(<version>) = #f, init-keyword: min-version:;
  constant slot max-version :: false-or(<version>) = #f, init-keyword: max-version:;
end class;

define method initialize
    (dep :: <dep>, #key package-name) => ()
  next-method();
  validate-package-name(package-name);
  let minv = dep.min-version;
  let maxv = dep.max-version;
  if (minv & maxv & ~(minv <= maxv))
    package-error("invalid dependency: %=", dep-to-string(dep));
  end;
end method;

define method print-object
    (dep :: <dep>, stream :: <stream>) => ()
  printing-object (dep, stream)
    write(stream, dep-to-string(dep));
  end;
end method;

define method \=
    (d1 :: <dep>, d2 :: <dep>) => (_ :: <bool>)
  istring=(d1.package-name, d2.package-name)
  & d1.min-version = d2.min-version
  & d1.max-version = d2.max-version
end method;

// TODO: I like the dependency syntax/semantics used by Cargo. Will
//       probably switch to those, but it can wait because for now we
//       mostly can use 'head'. Might be more complex than necessary?
define function dep-to-string
    (dep :: <dep>) => (_ :: <string>)
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
end function;

// TODO: validate package names against this when packages are added.
// Start out with a restrictive naming scheme. Can expand later if needed.
// define constant $package-name-regex :: <regex> = #regex:{([a-zA-Z][a-zA-Z0-9-]*)};
define constant $dependency-regex :: <regex>
  = begin
      let rev = #:string:"(\d+\.\d+\.\d+)";
      let range = concat(rev, "-", rev);
      let version-spec = concat(#:string:"(head|\*|([<=>])?", rev, "|", range, ")");
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
end function;

define function satisfies?
    (dep :: <dep>, version :: <version>) => (_ :: <bool>)
  let (minv, maxv) = values(dep.min-version, dep.max-version);
  (~minv & ~maxv)               // any version will do
    | (~maxv & version >= minv)
    | (~minv & version <= maxv)
    | (minv & maxv & version >= minv & version <= maxv)
end function;


// Something that knows how to grab a package off the net and unpack
// it into a directory.
define abstract class <transport> (<object>)
end class;

// Install git packages.
define class <git-transport> (<transport>)
  constant slot branch :: <string> = "master", init-keyword: branch:;
end class;

// TODO: mercurial, tarballs, ...

define function read-package-file
    (file :: <file-locator>) => (release :: false-or(<release>))
  verbose-message("Reading package file %s\n", file);
  block ()
    with-open-file (stream = file)
      let json = json/parse(stream, table-class: <istring-table>, strict?: #f);
      let name = element(json, "name", default: #f)
        | package-error("Invalid package file %s: expected a 'name' field.", file);
      let deps = element(json, "deps", default: #f)
        | package-error("Invalid package file %s: expected a 'deps' field.", file);
      let vstring = optional-element(name, json, "version", <string>)
        | $latest-name;
      let releases = make(<istring-table>);
      let release
        = make(<release>,
               package: make(<package>, name: name, releases: releases),
               deps: map-as(<dep-vector>, string-to-dep, deps),
               version: string-to-version(vstring),
               location: required-element(name, json, "location", <string>));
      releases[vstring] := release;
      release
    end
  exception (<file-does-not-exist-error>)
    #f
  end
end function;

// Forward various methods from <release> to the <package> that contains them.
define generic package-name         (o :: <object>) => (s :: <string>);
define generic package-synopsis     (o :: <object>) => (s :: <string>);
define generic package-description  (o :: <object>) => (s :: <string>);
define generic package-contact      (o :: <object>) => (s :: <string>);
define generic package-license-type (o :: <object>) => (s :: <string>);
define generic package-category     (o :: <object>) => (s :: <string>);
define generic package-keywords     (o :: <object>) => (s :: <seq>);

define not-inline method package-name
    (release :: <release>) => (s :: <string>)
  release.release-package.package-name
end method;

define method package-synopsis
    (release :: <release>) => (s :: <string>)
  release.release-package.package-synopsis
end method;

define method package-description
    (release :: <release>) => (s :: <string>)
  release.release-package.package-description
end method;

define method package-contact
    (release :: <release>) => (s :: <string>)
  release.release-package.package-contact
end method;

define method package-license-type
    (release :: <release>) => (s :: <string>)
  release.release-package.package-license-type
end method;

define method package-category
    (release :: <release>) => (s :: <string>)
  release.release-package.package-category
end method;

define method package-keywords
    (release :: <release>) => (s :: <seq>)
  release.release-package.package-keywords
end method;

// Describes a package and its versions.  Many of the slots here are optional
// because they're not required in pkg.json files.  The catalog enforces more
// requirements itself.
define class <package> (<object>)
  constant slot package-name :: <string>,
    required-init-keyword: name:;
  // Map from version number string to <release>. Each release contains the
  // data that changes with each new versioned release, plus a back-pointer to
  // the package it's a part of.
  // TODO: probably makes more sense to store this as a vector, newest to oldest.
  constant slot package-releases :: <istring-table>,
    required-init-keyword: releases:;

  constant slot package-synopsis :: <string>,
    init-keyword: synopsis:;
  constant slot package-description :: <string>,
    init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot package-contact :: <string>,
    init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot package-license-type :: <string>,
    init-keyword: license-type:;
  constant slot package-category :: <string> = $uncategorized,
    init-keyword: category:;
  constant slot package-keywords :: <seq> = #[],
    init-keyword: keywords:;
end class;

define not-inline method initialize
    (p :: <package>, #key name) => ()
  next-method();
  validate-package-name(name);
end method;

define method print-object
    (package :: <package>, stream :: <stream>) => ()
  printing-object (package, stream)
    format(stream, "%s, %d releases",
           package.package-name, package.package-releases.size);
  end;
end method;

define function find-release
    (p :: <package>, v :: <version>) => (r :: false-or(<release>))
  element(p.package-releases, version-to-string(v), default: #f)
end function;

define method to-table
    (p :: <package>) => (t :: <istring-table>)
  let releases = make(<istring-table>);
  for (release keyed-by vstring in p.package-releases)
    releases[vstring] := to-table(release);
  end;
  let package = make(<istring-table>);
  package["synopsis"] := p.package-synopsis;
  package["description"] := p.package-description;
  package["contact"] := p.package-contact;
  package["license-type"] := p.package-license-type;
  package["keywords"] := p.package-keywords;
  package["category"] := p.package-category;
  package["releases"] := releases;
  package
end method;
