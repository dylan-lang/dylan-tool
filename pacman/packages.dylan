Module: %pacman

define constant $head-name = "HEAD";
define constant $latest-name = "LATEST";

define constant <dep-vector> = limited(<vector>, of: <dep>);

// An error due to invalid or missing package attributes, badly specified
// dependencies, etc.
define class <package-error> (<simple-error>)
end class;

define function package-error (msg :: <string>, #rest args)
  error(make(<package-error>, format-string: msg, format-arguments: args));
end function;

///
/// Releases
///

// Represents a specific release of a package. Anything that might change for
// each release belongs here and anything that remains constant across all
// releases belongs in <package>.
define class <release> (<object>)
  // Back pointer to package containing this release.
  constant slot release-package :: <package>,
    required-init-keyword: package:;

  // Note that this may be a semantic version or a branch version even though technically
  // branch versions aren't usually considered releases. This is so that dependency
  // resolution and installation can be performed on them.
  constant slot release-version :: <version>,
    required-init-keyword: version:;

  // Dependencies required to build the main libraries. These are transitive to
  // anything depending on this release.
  constant slot release-dependencies :: <dep-vector> = as(<dep-vector>, #[]),
    init-keyword: dependencies:;

  // Development dependencies, for example testworks. These are not transitive.
  constant slot release-dev-dependencies :: <dep-vector> = as(<dep-vector>, #[]),
    init-keyword: dev-dependencies:;

  // Where the package can be downloaded from.
  constant slot release-url :: <string>,
    required-init-keyword: url:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot release-license :: <string>,
    required-init-keyword: license:;

  // Location of full license text.
  constant slot release-license-url :: false-or(<string>),
    init-keyword: license-url:;
end class;

define method print-object
    (release :: <release>, stream :: <stream>) => ()
  if (*print-escape?*)
    printing-object (release, stream)
      print(release, stream, escape?: #f);
    end;
  else
    format(stream, "%s@%s", release.package-name, release.release-version);
  end;
end method;

define function release-to-string
    (rel :: <release>) => (s :: <string>)
  with-output-to-string (s)
    print(rel, s, escape?: #f)
  end
end function;

// A package with the same name and version is guaranteed to have all
// other attributes the same.
//
// TODO: Document why this method was necessary because I sure don't remember.
//       More and more I think using this is a mistake since it's impossible to
//       search for callers.
define method \=
    (r1 :: <release>, r2 :: <release>) => (_ :: <bool>)
  string-equal-ic?(r1.package-name, r2.package-name)
    & r1.release-version = r2.release-version
end method;

// This method makes it easy to sort a list of releases newest to oldest.
// See resolve-deps for usage via `max`.
define method \<
    (r1 :: <release>, r2 :: <release>) => (_ :: <bool>)
  string-less-ic?(r1.package-name, r2.package-name)
    | r1.release-version < r2.release-version
end method;

// Start with restrictive package naming. Expand later if needed.
define constant $pkg-name-regex = #:regex:{^[A-Za-z][A-Za-z0-9._-]*$};

define function validate-package-name
    (name :: <string>) => ()
  re/search-strings($pkg-name-regex, name)
    | package-error("invalid package name: %=", name);
end function;

// Convert to table for outputing as JSON.
define method to-table
    (release :: <release>) => (t :: <istring-table>)
  let t = make(<istring-table>);
  t["version"] := version-to-string(release.release-version);
  t["dependencies"] := map-as(<vector>, dep-to-string, release.release-dependencies);
  t["dev-dependencies"]
    := map-as(<vector>, dep-to-string, release.release-dev-dependencies);
  // TODO: delete this after converting catalog
  t["deps"] := map-as(<vector>, dep-to-string, release.release-dependencies);
  t["url"] := release.release-url;
  t["license"] := release.release-license;
  if (release.release-license-url)
    t["license-url"] := release.release-license-url;
  end;
  t
end method;


///
/// Transports
///

// TODO(cgay): The Go module system supposedly uses only HTTP requests
// to download packages, to avoid requiring users to have source control
// clients installed. e.g., if we want to support both Mercurial and Git
// every user has to have both installed. Bad.

// Something that knows how to grab a package off the net and unpack
// it into a directory.
define abstract class <transport> (<object>)
end class;

// Install packages as git repositories.
define class <git-transport> (<transport>)
end class;

define function package-transport
    (release :: <release>) => (transport :: <transport>)
  let url :: <string> = release.release-url;
  if (starts-with?(url, "https://git") // github, gitlab, ...
      | starts-with?(url, "git@")
      | ends-with?(url, ".git"))
    make(<git-transport>)
  else
    package-error("No transport found for package URL %=", url);
  end
end function;

// Load the dylan-package.json file, which is subtly different from a package
// file in the catalog. People shouldn't have to know which attributes are
// package attributes and which are release attributes so in dylan-package.json
// they are all specified in one table and here we extract them and put them in
// the right place. There is no conflict since the file doesn't contain
// multiple releases.
define function load-dylan-package-file
    (file :: <file-locator>) => (release :: <release>)
  log-trace("Reading package file %s", file);
  with-open-file (stream = file)
    let json = block ()
                 json/parse(stream, table-class: <istring-table>, strict?: #f)
               exception (ex :: json/<error>)
                 package-error("%s %s", file, ex);
               end;
    if (~instance?(json, <table>))
      package-error("%s is not well-formed. It must be a JSON object like"
                      " { ...package attributes... }");
    end;
    decode-dylan-package-json(file, json)
  end
end function;

define function decode-dylan-package-json
    (file :: <file-locator>, json :: <istring-table>) => (r :: <release>)
  local
    method required-element
        (key :: <string>, expected-type :: <type>) => (value :: <object>)
      let v = element(json, key, default: #f)
        | package-error("%s missing required key %=.", file, key);
      instance?(v, expected-type)
        | package-error("%s: incorrect type for key %=: got %=, want %=",
                        file, key, object-class(v), expected-type);
      v
    end method,
    method optional-element
        (key :: <string>, expected-type :: <type>, default-value) => (value :: <object>)
      let v = element(json, key, default: default-value);
      if (v & ~instance?(v, expected-type))
        package-error("%s: incorrect type for key %=: got %=, want %=",
                      file, key, object-class(v), expected-type);
      end;
      v
    end method,
    method dependencies () => (deps :: <seq>)
      optional-element("dependencies", <seq>, #f)
        | begin
            let deps =  optional-element("deps", <seq>, #f);
            if (deps)
              // Even though we're in major version 0 I'm giving this a little
              // time to be updated since it will take me a while to get to all
              // the existing dylan-package.json files.
              log-warning("%s: the \"deps\" attribute is deprecated;"
                            " use \"dependencies\" instead.", file);
              deps
            end
          end
        | #()
    end method;
  // Warn about unrecognized keys.
  for (ignore keyed-by key in json)
    if (~member?(key, #["category", "contact", "dependencies",
                        "deps", // TODO: remove deprecated key
                        "description", "dev-dependencies", "keywords",
                        "license", "license-url", "name", "url", "version"],
                 test: string-equal-ic?))
      log-warning("%s: unrecognized key %= (ignored)", file, key);
    end;
  end;
  // Required elements
  let name = required-element("name", <string>);
  let description = required-element("description", <string>);
  let version = string-to-version(required-element("version", <string>));
  let url = required-element("url", <string>);
  // Optional elements
  let contact = optional-element("contact", <string>, "");
  let category = optional-element("category", <string>, "");
  let deps = map-as(<dep-vector>, string-to-dep, dependencies());
  let dev-deps = map-as(<dep-vector>, string-to-dep,
                        optional-element("dev-dependencies", <seq>, #()));
  let keywords = optional-element("keywords", <seq>, #[]);
  let license = optional-element("license", <string>, "Unknown");
  let license-url = optional-element("license-url", <string>, #f);

  let package = make(<package>,
                     name: name,
                     description: description,
                     contact: contact | "",
                     category: category | $uncategorized,
                     keywords: keywords);
  let release = make(<release>,
                     package: package,
                     version: version,
                     dependencies: deps,
                     dev-dependencies: dev-deps,
                     url: url,
                     license: license,
                     license-url: license-url);
  add-release(package, release);
  release
end function;

define generic package-name (o :: <object>) => (_ :: <string>);

define not-inline method package-name
    (release :: <release>) => (s :: <string>)
  release.release-package.package-name
end method;

// Describes a package and its releases.  Attributes defined here are expected
// to always apply to all releases of this package.  Some slots are optional
// because they're not required in dylan-package.json files.  The catalog
// enforces more requirements itself.
define class <package> (<object>)
  // See validate-package-name for naming requirements.
  constant slot package-name :: <string>,
    required-init-keyword: name:;

  // All releases of this package, ordered newest to oldest. Each release
  // contains the data that changes with each new versioned release, plus a
  // back-pointer to the package it's a part of. Currently it is possible for
  // the <head> version to be at the beginning of this sequence, but the plan
  // is to only allow <semantic-version>s.
  constant slot package-releases :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: releases:;

  // Description of the package. Should be relatively concise; as yet unclear,
  // but in some contexts probably only the first sentence will be displayed.
  constant slot package-description :: <string>,
    required-init-keyword: description:;

  // Who to contact with questions about this package. Maybe a mailing list /
  // group address.
  // TODO: make this a (possibly empty) sequence of strings.
  constant slot package-contact :: <string> = "",
    init-keyword: contact:;

  // The category this package should be listed under in a table of contents
  // for the entire catalog.
  // TODO: allow #f
  constant slot package-category :: <string> = "",
    init-keyword: category:;

  // A sequence of strings to aid in package searches. The plan is that these
  // will be valued higher than the same words that occur in the description.
  // No need to duplicate words that occur in the summary (above) though.
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

// Find a release in package `p` that matches version `v`.
define generic find-release
    (p :: <package>, v :: <version>, #key exact?) => (r :: false-or(<release>));

// Find a release in package `p` that matches version `v`. If `exact?` is true then
// major, minor, and patch must exactly match `v`. Otherwise find the lowest numbered
// release that matches `v`'s major version. Based on SemVer, anything with the same
// major version and >= minor and patch should be compatible.
define method find-release
    (p :: <package>, v :: <semantic-version>, #key exact? :: <bool>) => (r :: false-or(<release>))
  // Releases are ordered newest to oldest, so avoid checking all of them.
  block (return)
    let min = #f;
    let v-major = v.version-major;
    for (release in p.package-releases)
      let current = release.release-version;
      let c-major = current.version-major;
      if (c-major < v-major)
        return(~exact? & min);
      elseif (c-major = v-major)
        if (current = v)
          return(release);
        elseif (current < v)
          return(~exact? & min);
        else
          // current is > v and it's compatible because they have the same major version.
          // Keep going because there may be another minor version that is still > v but
          // closer to it.
          min := release;
        end;
      end;
    end for;
    ~exact? & min
  end block
end method;

// @latest finds the latest numbered release. Package releases are ordered newest to
// oldest so it is only necessary to find the first <semantic-version>.
define method find-release
    (p :: <package>, v :: <latest>, #key exact? :: <bool>) => (r :: false-or(<release>))
  ignore(exact?);
  block (return)
    let first = #f;           // Could be HEAD release, until we remove support for that.
    for (release in p.package-releases)
      first := first | release;
      if (instance?(release.release-version, <semantic-version>))
        return(release);
      end;
    end;
    first
  end
end method;

// Find a release for a branch version. Branches are arbitrary; we simply assume the
// branch exists and create a release for it.
//
// TODO(cgay): this is temporary while I attempt to bootstrap dylan-tool and
// right now it only works for packages that exist in the catalog because we
// need to find the location and deps. For now we find the latest release and
// take the information from it, but that's obviously not always going to be
// correct. I suspect the right solution for branch versions is to specify them
// fully in the deps. So instead of just "pacman@my-branch" we would have
// "https://gitlab.com/org/pacman@my-branch". That takes care of the location,
// but what about the deps? Do we rely on it having a dylan-package.json file
// and the user running `dylan update` again? That's terrible. Auto-detect
// dylan-package.json after download, and recompute deps? Try and fetch the
// dylan-package.json file right here? Assume no deps at all for branch
// versions? Don't support branch versions at all and make the user checkout
// the branch manually?
define method find-release
    (p :: <package>, v :: <branch-version>, #key exact? :: <bool>) => (r :: false-or(<release>))
  ignore(exact?);
  let release = find-release(p, $latest)
    | package-error("no release of %= found in catalog, which is currently"
                      " required for branch versions. version: %=", p, v);
  make(<release>,
       package: p,
       version: v,
       dependencies: release.release-dependencies,
       url: release.release-url)
end method;

define function add-release
    (pkg :: <package>, release :: <release>) => (r :: <release>)
  // package-releases is ordered by version, newest to oldest.
  let version = release.release-version;
  let releases = pkg.package-releases;
  block (done)
    for (rel in releases)
      let v = rel.release-version;
      if (v < version)
        add!(pkg.package-releases, release);
        sort!(pkg.package-releases, test: \>);
        done();
      elseif (v = version)
        if (rel ~= release)
          package-error("attempt to add different instance of release %s", release);
        end;
        done()
      end;
    end for;
    add!(pkg.package-releases, release);
    sort!(pkg.package-releases, test: \>);
  end block;
  release
end function;

define method to-table
    (pkg :: <package>) => (t :: <istring-table>)
  let t = make(<istring-table>);
  t["name"] := pkg.package-name;
  t["description"] := pkg.package-description;
  t["contact"] := pkg.package-contact;
  t["category"] := pkg.package-category;
  t["keywords"] := pkg.package-keywords;
  t["releases"] := pkg.package-releases;
  t
end method;
