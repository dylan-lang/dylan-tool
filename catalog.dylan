Module: %pacman

/*
TODO:
* do we specify the libraries contained in the package explicitly, or just
  let them be found via the .lid files?

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

define function load-catalog
    (#key store :: false-or(<storage>)) => (_ :: <catalog>)
  // TODO: handle type errors (e.g., from assumptions that the json is valid)
  //       and return <catalog-error>.
  // TODO: Use $catalog-url if local cache out of date, and update local cache.
  //       If we can't reach $catalog-url, fall-back to local cache.
  %load-catalog(store | local-cache())
end;

// Load a json-encoded catalog from file.
define method %load-catalog
    (store :: <json-file-storage>) => (_ :: <catalog>)
  with-open-file(stream = store.pathname,
                 direction: #"input",
                 if-does-not-exist: #f)
    let (cat, num-pkgs, num-versions) = read-json-catalog(stream);
    message("Loaded %d packages with %d versions from %s.",
            num-pkgs, num-versions, store.pathname);
    validate-catalog(cat);
    cat
  end
  | begin
      message("WARNING: No package catalog found in %s. Using empty catalog.",
              store.pathname);
      make(<catalog>)
    end
end;

define function read-json-catalog
    (stream :: <stream>, #key table-class)
 => (_ :: <catalog>, pkgs :: <int>, versions :: <int>)
  let json = json/parse(stream, table-class: table-class | <str-map>);
  json-to-catalog(json)
end;

define function json-to-catalog
    (json :: <str-map>) => (cat :: <catalog>, num-groups :: <int>, num-pkgs :: <int>)
  let num-pkgs = 0;
  let packages = make(<istr-map>);
  for (shared-attrs keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key) // unused for now
      if (element(shared-attrs, pkg-name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("Duplicate package group %=", pkg-name);
      end;
      let version->pkg = make(<istr-map>);
      for (version-attrs keyed-by version in shared-attrs["versions"])
        if (element(version->pkg, version, default: #f))
          catalog-error("Duplicate package version: %s/%s", pkg-name, version);
        end;
        version->pkg[version] :=
          make(<pkg>,
               name: pkg-name,
               version: string-to-version(version),
               source-url: version-attrs["source-url"],
               dependencies: map-as(<dep-vec>, string-to-dep, version-attrs["deps"]),
               // Shared attributes...
               synopsis: shared-attrs["synopsis"],
               description: shared-attrs["description"],
               contact: shared-attrs["contact"],
               license-type: shared-attrs["license-type"],
               category: element(shared-attrs, "category", default: #f),
               keywords: element(shared-attrs, "keywords", default: #f));
        num-pkgs := num-pkgs + 1;
      end for;
      packages[pkg-name] := version->pkg;
    end if;
  end for;
  values(make(<catalog>, package-map: packages), packages.size, num-pkgs)
end function json-to-catalog;

define method store-catalog
    (catalog :: <catalog>, store :: <json-file-storage>) => ()
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    write-json-catalog(catalog, stream)
  end;
end;

define function write-json-catalog
    (catalog :: <catalog>, stream :: <stream>) => ()
  let pkg-map = table(<istr-map>,
                      $catalog-attrs-key => table(<str-map>,
                                                  "unused" => "for now"));
  // In the Dylan data structures many attributes are duplicated in
  // each version of the <pkg> class because it's convenient. In the
  // json text we reduce that duplication by storing the shared
  // attributes in one table and then storing the attributes for
  // specific versions in sub-tables.
  for (version-dict keyed-by pkg-name in catalog.package-map)
    let version-map = make(<istr-map>);
    for (pkg keyed-by version in version-dict)
      if (~element(pkg-map, pkg-name, default: #f))
        pkg-map[pkg-name]
          := table("synopsis" => pkg.synopsis,
                   "description" => pkg.description,
                   "contact" => pkg.contact,
                   "license-type" => pkg.license-type,
                   "keywords" => pkg.keywords,
                   "category" => pkg.category,
                   "versions" => version-map);
      end;
      version-map[version]
        := table(<istr-map>,
                 "source-url" => pkg.source-url,
                 "deps" => map(dep-to-string, pkg.dependencies));
    end;
  end;
  json/encode(stream, pkg-map);
end function write-json-catalog;

define method find-package
    (name :: <str>, ver :: <str>) => (pkg :: <pkg>)
  %find-package(load-catalog(), name, string-to-version(ver))
  | catalog-error("package not found: %s/%s", name, ver);
end;

define function %find-package
    (cat :: <catalog>, name :: <str>, ver :: <version>) => (p :: false-or(<pkg>))
  let version-map = element(cat.package-map, name, default: #f);
  if (version-map & version-map.size > 0) 
    if (ver = $latest)
      let newest-first = sort(value-sequence(version-map),
                              test: method (p1, p2)
                                      p1.version > p2.version
                                    end);
      newest-first[0]
    else
      element(version-map, version-to-string(ver), default: #f)
    end
  end
end;

// Signal <catalog-error> if there are any problems found in the catalog.
define function validate-catalog (cat :: <catalog>) => ()
  for (version-map keyed-by pkg-name in cat.package-map)
    for (pkg keyed-by vstring in version-map)
      validate-dependencies(cat, pkg);
    end;
  end;
end;

// Verify that all dependencies specified in the catalog also exist in
// the catalog. Note this has nothing to do with whether or not
// they're installed.
define function validate-dependencies (cat :: <catalog>, pkg :: <pkg>) => ()
  local method missing-dep (dep)
          catalog-error("for package %s/%s, dependency %s is missing from the catalog",
                        pkg.name, version-to-string(pkg.version), dep-to-string(dep));
        end;
  for (dep in pkg.dependencies)
    let version-map = element(cat.package-map, dep.package-name, default: #f);
    if (~version-map)
      missing-dep(dep);
    end;
    block (return)
      for (pkg in version-map)
        if (version-satisfies?(dep, pkg.version))
          return()
        end;
      end;
      missing-dep(dep)
    end;
  end;
end;
