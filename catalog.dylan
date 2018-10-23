Module: %pacman

/*
TODO:
* do we specify package dependencies explicitly, or just
  let them be found via the .lid files?
* can the catalog itself (the pacman-catalog package) be installed like
  any other package and loaded from the install directory? 

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

// TODO:
//   * make description optional and default to synopsis.
define class <entry> (<any>)
  constant slot package :: <pkg>, required-init-keyword: package:;
  constant slot synopsis :: <str>, required-init-keyword: synopsis:;
  constant slot description :: <str>, required-init-keyword: description:;

  // Who to contact with questions about this package.
  constant slot contact :: <str>, required-init-keyword: contact:;

  // License type for this package, e.g. "MIT" or "BSD".
  constant slot license-type :: <str>, required-init-keyword: license-type:;
  constant slot category :: <str> = $uncategorized, init-keyword: category:;
  constant slot keywords :: <seq> = #[], init-keyword: keywords:;
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
  let packages = make(<istr-map>);
  for (shared-attrs keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key) // unused for now
      if (element(shared-attrs, pkg-name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("Duplicate package group %=", pkg-name);
      end;
      let entries = make(<istr-map>); // version string -> <entry>
      for (version-attrs keyed-by version in shared-attrs["versions"])
        if (element(entries, version, default: #f))
          catalog-error("Duplicate package version: %s/%s", pkg-name, version);
        end;
        entries[version] :=
          begin
            let deps = map-as(<dep-vec>, string-to-dep, version-attrs["deps"]);
            let pkg = make(<pkg>,
                           name: pkg-name,
                           version: string-to-version(version),
                           deps: deps,
                           location: version-attrs["location"]);
            // TODO: this is dumb now. just make one entry and have it contain a list of packages.
            make(<entry>,
                 package: pkg,
                 synopsis: shared-attrs["synopsis"],
                 description: shared-attrs["description"],
                 contact: shared-attrs["contact"],
                 license-type: shared-attrs["license-type"],
                 category: element(shared-attrs, "category", default: #f),
                 keywords: element(shared-attrs, "keywords", default: #f))
          end;
        num-pkgs := num-pkgs + 1;
      end for;
      packages[pkg-name] := entries;
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
  for (version-dict keyed-by pkg-name in catalog.package-map)
    let version-map = make(<istr-map>);
    for (entry keyed-by version in version-dict)
      if (~element(pkg-map, pkg-name, default: #f))
        pkg-map[pkg-name]
          := table("synopsis" => entry.synopsis,
                   "description" => entry.description,
                   "contact" => entry.contact,
                   "license-type" => entry.license-type,
                   "keywords" => entry.keywords,
                   "category" => entry.category,
                   "versions" => version-map);
      end;
      let pkg = entry.package;
      version-map[version]
        := table(<istr-map>,
                 "location" => pkg.location,
                 "deps" => map(dep-to-string, pkg.deps));
    end;
  end;
  json/encode(stream, pkg-map);
end function write-json-catalog;

define method find-package
    (cat :: <catalog>, name :: <str>, ver :: <str>) => (pkg :: false-or(<pkg>))
  find-package(cat, name, string-to-version(ver))
end;

define method find-package
    (cat :: <catalog>, name :: <str>, ver :: <version>) => (p :: false-or(<pkg>))
  let version-map = element(cat.package-map, name, default: #f);
  if (version-map & version-map.size > 0)
    if (ver = $latest)
      let newest-first = sort(value-sequence(version-map),
                              test: method (e1 :: <entry>, e2 :: <entry>)
                                      e1.package.version > e2.package.version
                                    end);
      newest-first[0].package
    else
      let entry = element(version-map, version-to-string(ver), default: #f);
      entry & entry.package
    end
  end
end;

// Signal <catalog-error> if there are any problems found in the catalog.
//
// TODO: verify (on load) that there aren't two entries for the same version number
//       or the same package name with different capitalization.
define function validate-catalog (cat :: <catalog>) => ()
  for (version-map keyed-by pkg-name in cat.package-map)
    for (entry keyed-by vstring in version-map)
      validate-deps(cat, entry.package);
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
    let version-map = element(cat.package-map, dep.package-name, default: #f);
    if (~version-map)
      missing-dep(dep);
    end;
    block (return)
      for (entry in version-map)
        if (satisfies?(dep, entry.package.version))
          return()
        end;
      end;
      missing-dep(dep)
    end;
  end;
end;

define function package-versions
    (cat :: <catalog>, pkg-name :: <str>) => (pkgs :: <pkg-vec>)
  let vmap = element(cat.package-map, pkg-name, default: #f);
  if (vmap)
    map-as(<pkg-vec>, identity, vmap)
  else
    #[]
  end;
end;
