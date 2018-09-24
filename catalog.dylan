Module: pacman

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

// TODO: a lot

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
  let text = with-open-file(stream = store.pathname,
                            direction: #"input",
                            if-does-not-exist: #f)
               read-to-end(stream)
             end;
  if (text)
    let json = parse-json(text);
    let (cat, num-pkgs, num-versions) = json-to-catalog(json);
    message("Loaded %d packages with %d versions from %s.",
            num-pkgs, num-versions, store.pathname);
    cat
  else
    message("WARNING: No package catalog found in %s. Using empty catalog.", store.pathname);
    make(<catalog>)
  end
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
       licence-type: group-attrs["license-type"],
       synopsis: group-attrs["synopsis"])
end;

define function json-to-pkg
    (version :: <str>, pkg-attrs :: <str-map>) => (_ :: <pkg>)
  make(<pkg>,
       version: string-to-version(version),
       dependencies: map(string-to-dep, pkg-attrs["deps"]),
       source-url: pkg-attrs["source-url"])
end;

define method store-catalog
    (catalog :: <catalog>, store :: <json-file-storage>)
  let groups = table(<istr-map>,
                     $catalog-attrs-key => table(<str-map>, "unused" => "for now"));
  for (group in catalog.package-groups)
    groups[group.name] := pkg-group-to-json(group);
  end;
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    encode-json(stream, groups);
  end;
end;

define function pkg-group-to-json
    (group :: <pkg-group>) => (json :: <str-map>)
  let versions = make(<istr-map>);
  for (pkg in group.packages)
    versions[version-to-string(pkg.version)] := pkg-to-json(pkg);
  end;
  table(<str-map>,
        "name" => group.name,
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
        "deps" => map(dep-to-string, pkg.dependencies),
        "source-url" => pkg.source-url)
end;

define method find-package
    (cat :: <catalog>, pkg-name :: <str>, ver :: <version>) => (pkg :: false-or(<pkg>))
  let group = element(cat.package-groups, pkg-name, default: #f);
  group &
    block (return)
      let latest = #f;
      for (pkg in group.packages)
        if (ver == $latest & (~latest | pkg.version > latest.version))
          latest := pkg;
        elseif (ver == pkg.version)
          return(pkg)
        end
      end for;
      latest
    end block
end;
