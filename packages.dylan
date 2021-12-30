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
  // Note that this may be a semantic version or a branch version even though technically
  // branch versions aren't usually considered releases. This is so that dependency
  // resolution and installation can be performed on them.
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
  istring=(r1.package-name, r2.package-name) & r1.release-version = r2.release-version
end method;

// This method makes it easy to sort a list of releases newest to oldest.
// See resolve-deps for usage via `max`.
define method \<
    (r1 :: <release>, r2 :: <release>) => (_ :: <bool>)
  istring<(r1.package-name, r2.package-name) | r1.release-version < r2.release-version
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
  tabling(<istring-table>,
          // Name and version are encoded higher up in the JSON object
          // structure.
          "deps" => map(dep-to-string, release.release-deps),
          "location" => release.release-location)
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
  let location :: <string> = release.release-location;
  if (starts-with?(location, "https://git") // github, gitlab, ...
      | starts-with?(location, "git@")
      | ends-with?(location, ".git"))
    make(<git-transport>)
  else
    package-error("No transport found for package URL %=", location);
  end
end function;

define function read-package-file
    (file :: <file-locator>) => (release :: false-or(<release>))
  log-trace("Reading package file %s", file);
  block ()
    with-open-file (stream = file)
      let json = block ()
                   json/parse(stream, table-class: <istring-table>, strict?: #f)
                 exception (ex :: json/<error>)
                   package-error("%s %s", file, ex);
                 end;
      let name = element(json, "name", default: #f)
        | package-error("Invalid package file %s: expected a 'name' field.", file);
      let deps = element(json, "deps", default: #f)
        | package-error("Invalid package file %s: expected a 'deps' field.", file);
      let vstring = optional-element(name, json, "version", <string>)
        | $latest-name;
      let summary = optional-element(name, json, "summary", <string>);
      let releases = make(<stretchy-vector>);
      let release
        = make(<release>,
               // This is different from when parsing packages in the catalog
               // in that more things are optional here.
               package: make(<package>,
                             name: name,
                             file: file,
                             releases: releases,
                             summary: summary | "**no summary**",
                             description: optional-element(name, json, "description", <string>)
                               | summary | "**no description**",
                             contact: optional-element(name, json, "contact", <string>)
                               | "**no contact**",
                             license-type: optional-element(name, json, "license-type", <string>)
                               | "**no license**",
                             category: optional-element(name, json, "category", <string>)
                               | $uncategorized,
                             keywords: optional-element(name, json, "keywords", <vector>)
                               | #[]),
               deps: map-as(<dep-vector>, string-to-dep, deps),
               version: string-to-version(vstring),
               location: required-element(name, json, "location", <string>));
      add!(releases, release);
      release
    end
  exception (<file-does-not-exist-error>)
    #f
  end
end function;

// Forward various methods from <release> to the <package> that contains them.
define generic package-name         (o :: <object>) => (_ :: <string>);
define generic package-file         (o :: <object>) => (_ :: false-or(<file-locator>));
define generic package-summary      (o :: <object>) => (_ :: <string>);
define generic package-description  (o :: <object>) => (_ :: <string>);
define generic package-contact      (o :: <object>) => (_ :: <string>);
define generic package-license-type (o :: <object>) => (_ :: <string>);
define generic package-category     (o :: <object>) => (_ :: <string>);
define generic package-keywords     (o :: <object>) => (_ :: <seq>);

define not-inline method package-name
    (release :: <release>) => (s :: <string>)
  release.release-package.package-name
end method;

define not-inline method package-file
    (release :: <release>) => (f :: false-or(<file-locator>))
  release.release-package.package-file
end method;

define method package-summary
    (release :: <release>) => (s :: <string>)
  release.release-package.package-summary
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

// Describes a package and its releases.  Many of the slots here are optional
// because they're not required in pkg.json files.  The catalog enforces more
// requirements itself.
//
// If you add slots to this you probably want to update the set of generics
// that forward from <release> to this, and the `to-table` method.
define class <package> (<object>)
  constant slot package-name :: <string>,
    required-init-keyword: name:;

  // pkg.json file from which this package was parsed, or #f if it was created
  // by loading the catalog.
  constant slot package-file :: false-or(<file-locator>) = #f,
    init-keyword: file:;

  // All releases of this package, ordered newest to oldest. Each release
  // contains the data that changes with each new versioned release, plus a
  // back-pointer to the package it's a part of. Currently it is possible for
  // the <head> version to be at the beginning of this sequence, but the plan
  // is to only allow <semantic-version>s.
  constant slot package-releases :: <seq>,
    required-init-keyword: releases:;

  // A one-liner to be displayed in the top-level table of contents of
  // packages. (May want to put a length limit on this.)
  constant slot package-summary :: <string>,
    required-init-keyword: summary:;

  // Full description of the package, which may be arbitrarily long. If this is
  // not supplied the summary may be used instead.
  constant slot package-description :: <string>,
    required-init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot package-contact :: <string>,
    required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  //
  // TODO: allow a full license to be specified, perhaps just a relative path
  // to the license file within the repo.
  constant slot package-license-type :: <string>,
    required-init-keyword: license-type:;

  // The category this package should be listed under in a table of contents
  // for the entire catalog.
  constant slot package-category :: <string>,
    required-init-keyword: category:;

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
    for (release in p.package-releases)
      let version = release.release-version;
      if (version = v)
        return(release)
      elseif (version < v)
        return(~exact? & min)
      elseif (version.version-major = v.version-major)
        // version is > v and it's compatible because they have the same major version.
        min := release;
      end;
    end;
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
// TODO(cgay): this is temporary while I attempt to bootstrap dylan-tool and right now it
// only works for packages that exist in the catalog because we need to find the location
// and deps. For now we find the latest release and take the information from it, but
// that's obviously not always going to be correct. I suspect the right solution for
// branch versions is to specify them fully in the deps. So instead of just
// "pacman@my-branch" we would have "https://gitlab.com/org/pacman@my-branch". That takes
// care of the location, but what about the deps? Do we rely on it having a pkg.json file
// and the user running `dylan update` again? That's terrible. Auto-detect pkg.json after
// download, and recompute deps? Try and fetch the pkg.json file right here? Assume no
// deps at all for branch versions? Don't support branch versions at all and make the
// user checkout the branch manually?
define method find-release
    (p :: <package>, v :: <branch-version>, #key exact? :: <bool>) => (r :: false-or(<release>))
  ignore(exact?);
  let release = find-release(p, $latest)
    | package-error("no release of %= found in catalog, which is currently"
                      " required for branch versions. version: %=", p, v);
  make(<release>,
       package: p,
       version: v,
       deps: release.release-deps,
       location: release.release-location)
end method;

define method to-table
    (p :: <package>) => (t :: <istring-table>)
  let releases = make(<istring-table>);
  for (release keyed-by vstring in p.package-releases)
    releases[vstring] := to-table(release);
  end;
  let package = make(<istring-table>);
  package["summary"] := p.package-summary;
  package["description"] := p.package-description;
  package["contact"] := p.package-contact;
  package["license-type"] := p.package-license-type;
  package["keywords"] := p.package-keywords;
  package["category"] := p.package-category;
  package["releases"] := releases;
  package
end method;
