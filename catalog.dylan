Module: %pacman

/*
json catalog format

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

define function catalog-error (fmt :: <str>, #rest args) => ()
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end;

// A datastore backed by a json file on disk. The json encoding is a
// top-level dictionary mapping package names to package objects,
// which are themselves encoded as json dictionaries. Almost all
// fields are required.
define class <json-file-storage> (<storage>)
  constant slot pathname :: <str>, required-init-keyword: pathname:;
end;

// TODO: for now we assume the catalog is a local file. should be fetched from some URL.
//define constant $catalog-url :: <uri> = "http://github.com/dylan-lang/package-catalog/catalog.json"

define constant $local-catalog-filename :: <str> = "catalog.json";

define function local-cache
    () => (_ :: <json-file-storage>)
  let path = merge-locators(as(<physical-locator>, $local-catalog-filename),
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
    cat
  end
  | begin
      message("WARNING: No package catalog found in %s. Using empty catalog.", store.pathname);
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
  let groups = make(<istr-map>);
  for (group-map keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key) // unused for now
      if (element(groups, pkg-name, default: #f))
        // This is probably a bug due to a difference in character
        // case when the package was added.
        catalog-error("Duplicate package group %=", pkg-name);
      end;
      let group = json-to-pkg-group(pkg-name, group-map);
      for (pkg in group.packages)
        pkg.group := group;
      end;
      groups[pkg-name] := group;
    end if;
  end for;
  values(make(<catalog>, package-groups: groups), groups.size, num-pkgs)
end function json-to-catalog;

define function json-to-pkg-group
    (pkg-name :: <str>, group-attrs :: <str-map>) => (_ :: <pkg-group>)
  let pkgs = #();
  for (pkg-attrs keyed-by version in group-attrs["versions"])
    pkgs := add(pkgs, json-to-pkg(version, pkg-attrs));
  end;
  make(<pkg-group>,
       name: pkg-name,
       packages: map-as(<pkg-vec>, identity, pkgs),
       contact: group-attrs["contact"],
       description: group-attrs["description"],
       category: element(group-attrs, "category", default: #f),
       keywords: element(group-attrs, "keywords", default: #f),
       license-type: group-attrs["license-type"],
       synopsis: group-attrs["synopsis"])
end;

define function json-to-pkg
    (version :: <str>, pkg-attrs :: <str-map>) => (_ :: <pkg>)
  make(<pkg>,
       version: string-to-version(version),
       dependencies: map-as(<dep-vec>, string-to-dep, pkg-attrs["deps"]),
       source-url: pkg-attrs["source-url"])
end;

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
  let groups = table(<istr-map>,
                     $catalog-attrs-key => table(<str-map>, "unused" => "for now"));
  for (group in catalog.package-groups)
    groups[group.name] := pkg-group-to-json(group);
  end;
  json/encode(stream, groups);
end;

define function pkg-group-to-json
    (group :: <pkg-group>) => (json :: <str-map>)
  let versions = make(<istr-map>);
  for (pkg in group.packages)
    versions[version-to-string(pkg.version)] := pkg-to-json(pkg);
  end;
  table(<str-map>,
        "synopsis" => group.synopsis,
        "description" => group.description,
        "contact" => group.contact,
        "license-type" => group.license-type,
        "keywords" => group.keywords,
        "category" => group.category,
        "versions" => versions)
end;

define function pkg-to-json
    (pkg :: <pkg>) => (json :: <str-map>)
  table(<str-map>,
        "deps" => map-as(<vector>, dep-to-string, pkg.dependencies),
        "source-url" => pkg.source-url)
end;

define method find-package
    (cat :: <catalog>, pkg-name :: <str>, ver :: <str>) => (pkg :: false-or(<pkg>))
  find-package(cat, pkg-name, string-to-version(ver))
end;

define method find-package
    (cat :: <catalog>, pkg-name :: <str>, ver :: <version>) => (pkg :: false-or(<pkg>))
  let group = element(cat.package-groups, pkg-name, default: #f);
  group & group.packages.size > 0 &
    if (ver = $latest)
      let newest-first = sort(group.packages,
                              test: method (p1, p2)
                                      p1.version > p2.version
                                    end);
      newest-first[0]
    else
      block (return)
        for (pkg in group.packages)
          if (pkg.version = ver)
            return(pkg)
          end
        end for
      end block
    end if
end;
