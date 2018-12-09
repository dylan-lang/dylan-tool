Module: %pacman

/*
json catalog format:

* Order within a json object is never guaranteed.
* Package names with leading "__" (double underscore) are reserved.
{
  "__catalog_attributes": { ... catalog metadata ... },
  "http": {
    "license": "MIT",
    "synopsis": "HTTP server and client",
    ...
    "versions": {
      "1.0.0": { ... http 1.0.0 attributes ... },
      "1.2.3": { ... http 1.2.3 attributes ... }
    },
  },
  "json": { ... },
  ...
}

*/

define constant $catalog-attrs-key = "__catalog_attributes";

// Point this at your checkout of pacman-catalog/catalog.json when
// testing additions to the catalog and the catalog will be loaded
// from here.
define constant $catalog-env-var = "DYLAN_CATALOG";

define class <catalog-error> (<package-error>)
end;

define function catalog-error (fmt :: <string>, #rest args)
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end;

// Forward various methods from pkg to the catalog entry that contains them.
define generic synopsis     (a :: <object>) => (s :: <string>);
define generic description  (a :: <object>) => (s :: <string>);
define generic contact      (a :: <object>) => (s :: <string>);
define generic license-type (a :: <object>) => (s :: <string>);
define generic category     (a :: <object>) => (s :: <string>);
define generic keywords     (a :: <object>) => (s :: <seq>);

define method synopsis     (p :: <pkg>) => (s :: <string>) p.entry.synopsis end;
define method description  (p :: <pkg>) => (s :: <string>) p.entry.description end;
define method contact      (p :: <pkg>) => (s :: <string>) p.entry.contact end;
define method license-type (p :: <pkg>) => (s :: <string>) p.entry.license-type end;
define method category     (p :: <pkg>) => (s :: <string>) p.entry.category end;
define method keywords     (p :: <pkg>) => (s :: <seq>) p.entry.keywords end;

define class <entry> (<object>)
  // Map from version number string to <pkg>. Each package contains
  // the data that can change with each version, plus a back-pointer
  // to the <entry> that contains it.
  constant slot versions :: <istring-table>, required-init-keyword: versions:;

  constant slot synopsis :: <string>, required-init-keyword: synopsis:;
  constant slot description :: <string>, required-init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot contact :: <string>, required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot license-type :: <string>, required-init-keyword: license-type:;
  constant slot category :: <string> = $uncategorized, init-keyword: category:;
  constant slot keywords :: <seq> = #[], init-keyword: keywords:;
end;

define function package-names (cat :: <catalog>) => (names :: <seq>)
  key-sequence(cat.entries)
end;

define function find-entry
    (cat :: <catalog>, pkg-name :: <string>) => (e :: false-or(<entry>))
  element(cat.entries, pkg-name, default: #f)
end;

define method to-table (e :: <entry>) => (t :: <istring-table>)
  let v = make(<istring-table>);
  for (pkg keyed-by vstring in e.versions)
    v[vstring] := to-table(pkg);
  end;
  table(<istring-table>,
        "synopsis" => e.synopsis,
        "description" => e.description,
        "contact" => e.contact,
        "license-type" => e.license-type,
        "keywords" => e.keywords,
        "category" => e.category,
        "versions" => v)
end;

define constant $catalog-pkg :: <pkg> =
  make(<pkg>,
       name: "pacman-catalog",
       version: $head,
       location: "https://github.com/dylan-lang/pacman-catalog");

define constant $local-catalog-filename :: <string> = "local-catalog.json";

// Loading the catalog once per session should be enough, so cache it here.
define variable *catalog* :: false-or(<catalog>) = #f;

// TODO: handle type errors (e.g., from assumptions that the json is valid)
//       and return <catalog-error>.
define function load-catalog () => (c :: <catalog>)
  let override = os/getenv($catalog-env-var);
  if (override & ~empty?(override))
    // If there's an override the assumption is that someone is adding
    // new packages or versions to the catalog and then testing, so
    // reload the catalog each time.
    *catalog* := load-local-catalog(as(<file-locator>, override))
  else
    let local-path = merge-locators(as(<file-locator>, $local-catalog-filename),
                                    package-manager-directory());
    *catalog*
      | (*catalog* := begin
                        if (install($catalog-pkg, force?: too-old?(local-path)))
                          copy-to-local-cache($catalog-pkg, local-path);
                        end;
                        load-local-catalog(local-path)
                      end)
  end
end;

define constant $catalog-freshness :: <duration> = make(<duration>, hours: 1);

define function too-old? (path :: <file-locator>) => (old? :: <bool>)
  block ()
    let mod-time = file-property(path, #"modification-date");
    let now = current-date();
    now - mod-time > $catalog-freshness
  exception (e :: <file-system-error>)
    // TODO: catch <file-does-not-exist-error> instead
    // https://github.com/dylan-lang/opendylan/issues/1147
    #t
  end
end;

define function copy-to-local-cache (pkg :: <pkg>, local-path :: <file-locator>)
  let pkg-path = merge-locators(as(<file-locator>, "catalog.json"),
                                source-directory(pkg));
  with-open-file (input = pkg-path)
    with-open-file (output = local-path,
                    direction: #"output",
                    if-exists: #"overwrite")
      write(output, read-to-end(input))
    end;
  end;
end;

define function load-local-catalog (path :: <file-locator>) => (c :: <catalog>)
  with-open-file(stream = path,
                 direction: #"input" /*,  I thought this was supposed to work:
                 if-does-not-exist: #f */)
    let (cat, num-pkgs, num-versions) = read-json-catalog(stream);
    message("Loaded %d package%s with %d version%s from %s.\n",
            num-pkgs, iff(num-pkgs == 1, "", "s"),
            num-versions, iff(num-versions == 1, "", "s"),
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
end;

define function read-json-catalog
    (stream :: <stream>, #key table-class)
 => (_ :: <catalog>, pkgs :: <int>, versions :: <int>)
  let json = json/parse(stream, table-class: table-class | <string-table>,
                        strict?: #f); // allow comments
  json-to-catalog(json)
end;

define function json-to-catalog
    (json :: <string-table>) => (cat :: <catalog>, num-groups :: <int>, num-pkgs :: <int>)
  let num-pkgs = 0;
  let entries = make(<istring-table>);
  for (entry-attrs keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key) // unused for now
      if (element(entry-attrs, pkg-name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("Duplicate catalog entry %=", pkg-name);
      end;
      let packages = make(<istring-table>); // version string -> <pkg>
      let entry = make(<entry>,
                       versions: packages,
                       synopsis: entry-attrs["synopsis"],
                       description: element(entry-attrs, "description", default: #f)
                                      | entry-attrs["synopsis"],
                       contact: entry-attrs["contact"],
                       license-type: entry-attrs["license-type"],
                       category: element(entry-attrs, "category", default: #f),
                       keywords: element(entry-attrs, "keywords", default: #f));
      entries[pkg-name] := entry;
      for (version-attrs keyed-by version in entry-attrs["versions"])
        if (element(packages, version, default: #f))
          catalog-error("Duplicate package version: %s %s", pkg-name, version);
        end;
        // Note that the following will err on invalid version
        // strings, which is intentional.
        let ver = string-to-version(version);
        if (ver = $latest)
          catalog-error("Version 'latest' is not a valid package version in the catalog."
                          " It's only valid for lookup. Did you mean 'head'?");
        end;
        packages[version] :=
          make(<pkg>,
               name: pkg-name,
               version: ver,
               deps: map-as(<dep-vec>, string-to-dep, version-attrs["deps"]),
               location: version-attrs["location"],
               entry: entry);
        num-pkgs := num-pkgs + 1;
      end for;
      entries[pkg-name] := entry;
    end if;
  end for;
  values(make(<catalog>, entries: entries), entries.size, num-pkgs)
end function json-to-catalog;

define method find-package
    (cat :: <catalog>, name :: <string>, ver :: <string>) => (pkg :: false-or(<pkg>))
  find-package(cat, name, string-to-version(ver))
end;

// Find the latest numbered version of a package.
define method find-package
    (cat :: <catalog>, name :: <string>, ver :: <latest>) => (p :: false-or(<pkg>))
  let entry = element(cat.entries, name, default: #f);
  if (entry & entry.versions.size > 0)
    let newest-first = sort(value-sequence(entry.versions),
                            test: method (p1 :: <pkg>, p2 :: <pkg>)
                                    p1.version > p2.version
                                  end);
    let latest = newest-first[0];
    // The concept of "latest" doesn't mean much if it always returns
    // the "head" version, which is latest by definition. So make sure
    // to only return the "head" version if there are no numbered
    // versions.
    if (latest.version = $head & newest-first.size > 1)
      latest := newest-first[1];
    end;
    latest
  end
end;

define method find-package
    (cat :: <catalog>, name :: <string>, ver :: <version>) => (p :: false-or(<pkg>))
  let entry = element(cat.entries, name, default: #f);
  if (entry)
    element(entry.versions, version-to-string(ver), default: #f)
  end
end;

// Signal <catalog-error> if there are any problems found in the catalog.
define function validate-catalog (cat :: <catalog>) => ()
  for (entry keyed-by pkg-name in cat.entries)
    for (pkg keyed-by vstring in entry.versions)
      validate-deps(cat, pkg);
    end;
  end;
end;

// Verify that all dependencies specified in the catalog also exist in
// the catalog. Note this has nothing to do with whether or not
// they're installed.
define function validate-deps (cat :: <catalog>, pkg :: <pkg>) => ()
  local method missing-dep (dep)
          catalog-error("for package %s/%s, dependency %s is missing from the catalog",
                        pkg.name, version-to-string(pkg.version), dep-to-string(dep));
        end;
  for (dep in pkg.deps)
    let entry = element(cat.entries, dep.package-name, default: #f);
    if (~entry)
      missing-dep(dep);
    end;
    block (return)
      for (pkg in entry.versions)
        if (satisfies?(dep, pkg.version))
          return()
        end;
      end;
      missing-dep(dep)
    end;
  end;
end;

define function package-versions
    (cat :: <catalog>, pkg-name :: <string>) => (pkgs :: <pkg-vec>)
  let entry = element(cat.entries, pkg-name, default: #f);
  if (entry)
    map-as(<pkg-vec>, identity, value-sequence(entry.versions))
  else
    as(<pkg-vec>, #[])
  end;
end;
