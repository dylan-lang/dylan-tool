Module: %pacman

/*
json catalog format:

* Order within a json object is never guaranteed.
* Package names with leading "__" (double underscore) are reserved.
{
  "__catalog_attributes": { ... catalog metadata ... },
  "http": {
    "license": "MIT",
    "summary": "HTTP server and client",
    ...
    "releases": {
      "1.0.0": { ... http 1.0.0 attributes ... },
      "1.2.3": { ... http 1.2.3 attributes ... }
    },
  },
  "json": { ... },
  ...
}

*/

define constant $catalog-attrs-key = "__catalog_attributes";

// Point this at your checkout of pacman-catalog/catalog.json when testing
// additions to the catalog and the catalog will be loaded from here.
define constant $catalog-env-var = "DYLAN_CATALOG";

define class <catalog-error> (<package-error>)
end class;

define function catalog-error
    (fmt :: <string>, #rest args)
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end function;

// Packages with no category are categorized thusly.
define constant $uncategorized = "Uncategorized";

define constant $catalog-package-release :: <release>
  = begin
      let releases = make(<istring-table>);
      let package = make(<package>,
                         name: "pacman-catalog",
                         releases: releases,
                         summary: "The pacman catalog",
                         description: "The pacman catalog",
                         contact: "carlgay@gmail.com",
                         license-type: "MIT",
                         category: $uncategorized);
      let release = make(<release>,
                         package: package,
                         version: $head,
                         location: "https://github.com/cgay/pacman-catalog",
                         deps: as(<dep-vector>, #[]));
      releases[$head-name] := release;
      release
    end;

define constant $local-catalog-filename :: <string> = "local-catalog.json";

// The catalog knows what packages (and versions thereof) exist.
define sealed class <catalog> (<object>)
  // package name string -> <package>
  constant slot all-packages :: <istring-table>,
    required-init-keyword: packages:;
end class;

define function package-names
    (cat :: <catalog>) => (names :: <seq>)
  key-sequence(cat.all-packages)
end function;

define function find-package
    (cat :: <catalog>, name :: <string>) => (p :: false-or(<package>))
  element(cat.all-packages, name, default: #f)
end function;

// Loading the catalog once per session should be enough, so cache it here.
define variable *catalog* :: false-or(<catalog>) = #f;

// TODO: handle type errors (e.g., from assumptions that the json is valid)
//       and return <catalog-error>.
define function load-catalog
    () => (c :: <catalog>)
  if (*catalog*)
    *catalog*
  else
    let override = os/getenv($catalog-env-var);
    let local-path
      = if (override)
          as(<file-locator>, override)
        else
          merge-locators(as(<file-locator>, $local-catalog-filename),
                         package-manager-directory());
        end;
    *catalog*
      := begin
           if (install($catalog-package-release, force?: too-old?(local-path)))
             copy-to-local-cache($catalog-package-release, local-path);
           end;
           load-local-catalog(local-path)
         end
  end
end function;

define constant $catalog-freshness :: <duration> = make(<duration>, hours: 1);

define function too-old?
    (path :: <file-locator>) => (old? :: <bool>)
  block ()
    let mod-time = file-property(path, #"modification-date");
    let now = current-date();
    now - mod-time > $catalog-freshness
  exception (<file-system-error>)
    // TODO: catch <file-does-not-exist-error> instead
    // https://github.com/dylan-lang/opendylan/issues/1147
    #t
  end
end function;

define function copy-to-local-cache
    (pkg :: <release>, local-path :: <file-locator>)
  let pkg-path = merge-locators(as(<file-locator>, "catalog.json"),
                                source-directory(pkg));
  with-open-file (input = pkg-path)
    with-open-file (output = local-path,
                    direction: #"output",
                    if-exists: #"overwrite")
      write(output, read-to-end(input))
    end;
  end;
end function;

define function load-local-catalog
    (path :: <file-locator>) => (c :: <catalog>)
  with-open-file(stream = path,
                 direction: #"input" /*,  I thought this was supposed to work:
                 if-does-not-exist: #f */)
    let (cat, num-packages, num-releases) = read-json-catalog(stream);
    verbose-message("Loaded %d package%s with %d release%s from %s.\n",
                    num-packages, iff(num-packages == 1, "", "s"),
                    num-releases, iff(num-releases == 1, "", "s"),
                    path);
    validate-catalog(cat);
    cat
  end
/*
  | begin
      message("WARNING: No package catalog found in %s. Using empty catalog.\n", path);
      make(<catalog>)
    end
*/
end function;

define function read-json-catalog
    (stream :: <stream>, #key table-class)
 => (c :: <catalog>, npackages :: <int>, nreleases :: <int>)
  let json = json/parse(stream, table-class: table-class | <string-table>,
                        strict?: #f); // allow comments
  json-to-catalog(json)
end function;

define function json-to-catalog
    (json :: <string-table>)
 => (cat :: <catalog>, npackages :: <int>, nreleases :: <int>)
  let nreleases = 0;
  let packages = make(<istring-table>);
  for (attributes keyed-by name in json)
    if (name ~= $catalog-attrs-key) // unused for now
      if (element(attributes, name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("duplicate package %=", name);
      end;
      let summary = required-element(name, attributes, "summary", <string>);
      let package
        = make(<package>,
               name: name,
               summary: summary,
               description: optional-element(name, attributes, "description", <string>)
                 | summary,
               contact: required-element(name, attributes, "contact", <string>),
               license-type: required-element(name, attributes, "license-type", <string>),
               category: optional-element(name, attributes, "category", <string>)
                 | $uncategorized,
               keywords: optional-element(name, attributes, "keywords", <seq>)
                 | #[]);
      json-to-releases(package,
                       required-element(name, attributes, "releases", <table>));
      packages[name] := package;
      nreleases := nreleases + package.package-releases.size;
    end if;
  end for;
  values(make(<catalog>, packages: packages),
         packages.size,
         nreleases)
end function;

define function json-to-releases
    (package :: <package>, attributes :: <string-table>)
 => ()
  let name = package.package-name;
  let releases = package.package-releases;
  for (release-attributes keyed-by vstring in attributes)
    // TODO: This test will fail when I make "1.2" parse the same as "1.2.0"
    if (element(releases, vstring, default: #f))
      catalog-error("duplicate package version: %s %s", name, vstring);
    end;
    let version = string-to-version(vstring);
    if (version = $latest)
      catalog-error("version 'latest' is not a valid package version in the catalog;"
                      " it's only valid for lookup. Did you mean 'head'?");
    end;
    releases[vstring]
      := make(<release>,
              version: version,
              deps: map-as(<dep-vector>,
                           string-to-dep,
                           required-element(name, release-attributes, "deps", <seq>)),
              location: required-element(name, release-attributes, "location", <string>),
              package: package);
  end for;
end function;

define function required-element
    (name :: <string>, table :: <table>, key :: <string>, expected-type :: <type>)
 => (value :: <object>)
  // TODO: error message could be better if we had a `context` parameter.
  let v = element(table, key, default: #f)
    | catalog-error("package %= missing required key %=. table = %s",
                    name, key,
                    with-output-to-string (s)
                      for (v keyed-by k in table)
                        format(s, "%= => %=\n", k, v)
                      end;
                    end);
  instance?(v, expected-type)
    | catalog-error("package %=, incorrect type for key %=: %=",
                    name, key, expected-type);
  v
end function;

define function optional-element
    (package-name :: <string>, table :: <table>, key :: <string>, expected-type :: <type>)
 => (value :: <object>)
  // TODO: error message could be better if we had a `context` parameter.
  let v = element(table, key, default: #f);
  if (v & ~instance?(v, expected-type))
    catalog-error("package %=, incorrect type for key %=: %=",
                  package-name, key, expected-type);
  end;
  v
end function;

// Exported
define generic find-package-release
    (catalog :: <catalog>, name :: <string>, version :: <object>)
 => (release :: false-or(<release>));

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <string>)
 => (p :: false-or(<release>))
  find-package-release(cat, name, string-to-version(ver))
end method;

// Find the latest released version of a package.
define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <latest>)
 => (p :: false-or(<release>))
  let package = find-package(cat, name);
  let releases = package & package.package-releases;
  if (releases & releases.size > 0)
    let newest-first = sort(value-sequence(releases),
                            test: method (r1 :: <release>, r2 :: <release>)
                                    r1.release-version > r2.release-version
                                  end);
    let latest = newest-first[0];
    // The concept of "latest" doesn't mean much if it always returns
    // the "head" version, which is latest by definition. So make sure
    // to only return the "head" version if there are no numbered
    // versions.
    if (latest.release-version = $head & newest-first.size > 1)
      latest := newest-first[1];
    end;
    latest
  end
end method;

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <version>)
 => (p :: false-or(<release>))
  let package = find-package(cat, name);
  package & find-release(package, ver)
end method;

// Signal <catalog-error> if there are any problems found in the catalog.
define function validate-catalog
    (cat :: <catalog>) => ()
  for (package keyed-by name in cat.all-packages)
    for (release keyed-by vstring in package.package-releases)
      validate-deps(cat, release);
    end;
  end;
end function;

// Verify that all dependencies specified in the catalog also exist as packages
// themselves in the catalog. Note this has nothing to do with whether or not
// they're installed.
define function validate-deps
    (cat :: <catalog>, release :: <release>) => ()
  local
    method dep-missing (dep)
      catalog-error("for package %s/%s, dependency %s is missing from the catalog",
                    release.package-name,
                    version-to-string(release.release-version),
                    dep-to-string(dep));
    end;
  for (dep in release.release-deps)
    let package = find-package(cat, dep.package-name);
    package | dep-missing(dep);
    any?(method (release)
           satisfies?(dep, release.release-version)
         end,
         package.package-releases)
      | dep-missing(dep);
  end;
end function;
