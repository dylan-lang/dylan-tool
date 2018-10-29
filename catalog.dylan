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

define constant $catalog-attrs-key :: <str> = "__catalog_attributes";

define class <catalog-error> (<package-error>)
end;

define function catalog-error (fmt :: <str>, #rest args)
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end;

// Forward various methods from pkg to the cataleg entry that contains it.
define generic synopsis     (a :: <any>) => (s :: <str>);
define generic description  (a :: <any>) => (s :: <str>);
define generic contact      (a :: <any>) => (s :: <str>);
define generic license-type (a :: <any>) => (s :: <str>);
define generic category     (a :: <any>) => (s :: <str>);
define generic keywords     (a :: <any>) => (s :: <seq>);

define method synopsis     (p :: <pkg>) => (s :: <str>) p.entry.synopsis end;
define method description  (p :: <pkg>) => (s :: <str>) p.entry.description end;
define method contact      (p :: <pkg>) => (s :: <str>) p.entry.contact end;
define method license-type (p :: <pkg>) => (s :: <str>) p.entry.license-type end;
define method category     (p :: <pkg>) => (s :: <str>) p.entry.category end;
define method keywords     (p :: <pkg>) => (s :: <seq>) p.entry.keywords end;

define class <entry> (<any>)
  // Map from version number string to <pkg>. Each package contains
  // the data that can change with each version, plus a back-pointer
  // to the <entry> that contains it.
  constant slot versions :: <istr-map>, required-init-keyword: versions:;

  constant slot synopsis :: <str>, required-init-keyword: synopsis:;
  constant slot description :: <str>, required-init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot contact :: <str>, required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot license-type :: <str>, required-init-keyword: license-type:;
  constant slot category :: <str> = $uncategorized, init-keyword: category:;
  constant slot keywords :: <seq> = #[], init-keyword: keywords:;
end;

define method to-table (e :: <entry>) => (t :: <istr-map>)
  let v = make(<istr-map>);
  for (pkg keyed-by vstring in e.versions)
    v[vstring] := to-table(pkg);
  end;
  table(<istr-map>,
        "synopsis" => e.synopsis,
        "description" => e.description,
        "contact" => e.contact,
        "license-type" => e.license-type,
        "keywords" => e.keywords,
        "category" => e.category,
        "versions" => v)
end;

// A datastore backed by a json file on disk. The json encoding is a
// top-level dictionary mapping package names to package objects,
// which are themselves encoded as json dictionaries. Almost all
// fields are required.
define class <json-file-storage> (<storage>)
  constant slot pathname :: <pathname>, required-init-keyword: pathname:;
end;

// TODO: for now we assume the catalog is a local file. should be fetched from some URL.
//define constant $catalog-url :: <uri> = "http://github.com/dylan-lang/package-catalog/catalog.json"

define constant $local-catalog-filename :: <str> = "catalog.json";

define function local-cache
    () => (_ :: <json-file-storage>)
  let path = merge-locators(as(<file-system-file-locator>, $local-catalog-filename),
                            package-manager-directory());
  make(<json-file-storage>, pathname: path)
end;

// Loading the catalog once per session should be enough, so cache it here.
define variable *catalog* :: false-or(<catalog>) = #f;

define method load-catalog () => (_ :: <catalog>)
  // TODO: handle type errors (e.g., from assumptions that the json is valid)
  //       and return <catalog-error>.
  // TODO: Use $catalog-url if local cache out of date, and update local cache.
  //       If we can't reach $catalog-url, fall-back to local cache.
  *catalog* | (*catalog* := %load-catalog(local-cache()))
end;

// Load a json-encoded catalog from file.
define method %load-catalog
    (store :: <json-file-storage>) => (_ :: <catalog>)
  with-open-file(stream = store.pathname,
                 direction: #"input",
                 if-does-not-exist: #f)
    let (cat, num-pkgs, num-versions) = read-json-catalog(stream);
    message("Loaded %d package%s with %d version%s from %s.\n",
            num-pkgs, iff(num-pkgs == 1, "", "s"),
            num-versions, iff(num-versions == 1, "", "s"),
            store.pathname);
    validate-catalog(cat);
    cat
  end
  | begin
      message("WARNING: No package catalog found in %s. Using empty catalog.\n",
              store.pathname);
      make(<catalog>)
    end
end;

define function read-json-catalog
    (stream :: <stream>, #key table-class)
 => (_ :: <catalog>, pkgs :: <int>, versions :: <int>)
  let json = json/parse(stream, table-class: table-class | <str-map>,
                        strict?: #f); // allow comments
  json-to-catalog(json)
end;

define function json-to-catalog
    (json :: <str-map>) => (cat :: <catalog>, num-groups :: <int>, num-pkgs :: <int>)
  let num-pkgs = 0;
  let entries = make(<istr-map>);
  for (entry-attrs keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key) // unused for now
      if (element(entry-attrs, pkg-name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("Duplicate catalog entry %=", pkg-name);
      end;
      let packages = make(<istr-map>); // version string -> <pkg>
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

define method store-catalog
    (cat :: <catalog>, store :: <json-file-storage>) => ()
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    write-json-catalog(cat, stream)
  end;
end;

define function write-json-catalog
    (cat :: <catalog>, stream :: <stream>) => ()
  let t = table(<istr-map>,
                $catalog-attrs-key => table(<str-map>,
                                            "unused" => "for now"));
  for (entry keyed-by pkg-name in cat.entries)
    t[pkg-name] := to-table(entry)
  end;
  json/encode(stream, t);
end;

define method find-package
    (cat :: <catalog>, name :: <str>, ver :: <str>) => (pkg :: false-or(<pkg>))
  find-package(cat, name, string-to-version(ver))
end;

define method find-package
    (cat :: <catalog>, name :: <str>, ver :: <version>) => (p :: false-or(<pkg>))
  let entry = element(cat.entries, name, default: #f);
  if (entry & entry.versions.size > 0)
    if (ver = $latest)
      let newest-first = sort(value-sequence(entry.versions),
                              test: method (p1 :: <pkg>, p2 :: <pkg>)
                                      p1.version > p2.version
                                    end);
      newest-first[0]
    else
      element(entry.versions, version-to-string(ver), default: #f)
    end
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
    (cat :: <catalog>, pkg-name :: <str>) => (pkgs :: <pkg-vec>)
  let entry = element(cat.entries, pkg-name, default: #f);
  if (entry)
    map-as(<pkg-vec>, identity, value-sequence(entry.versions))
  else
    #[]
  end;
end;
