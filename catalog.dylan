Module: package-manager

/*
json catalog format

* Order within a json object is never guaranteed.
* Package names with leading "__" (double underscore) are reserved.
{
  "__catalog": { ... catalog metadata ... }
  "http": {
    "__package": { ... package group attributes ... }
    "1.0.0": { ... http 1.0.0 attributes ... }
    "1.2.3": { ... http 1.2.3 attributes ... }
  }
  "json": { ... }
  ...
}

*/

// TODO: replace all calls to error() with the correct error types.

// TODO: locking

define constant $catalog-attrs-key :: <str> = "__catalog_attributes";
define constant $package-group-attrs-key :: <str> = "__package_group_attributes";

define class <catalog-error> (<package-error>)
end;

define function invalid-catalog-data-error
    (fmt :: <str>, #rest args) => ()
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
    () => (s :: <json-file-storage>)
  let path = merge-locators(as(<physical-locator>, $local-catalog-filename),
                            package-manager-directory());
  make(<json-file-storage>, pathname: path)
end;

define function load-catalog
    (#key store :: false-or(<storage>)) => (cat :: <catalog>)
  // TODO: Use $catalog-url if local cache out of date, and update local cache.
  //       If we can't reach $catalog-url, fall-back to local cache.
  %load-catalog(store | local-cache())
end;

// Load a json-encoded catalog from file.
define method %load-catalog
    (store :: <json-file-storage>) => (cat :: <catalog>)
  let json = with-open-file(stream = store.pathname,
                            direction: #"input",
                            if-does-not-exist: #f)
               parse-json(read-to-end(stream))
             end;
  if (json)
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
    (json :: <any>) => (cat :: <catalog>, num-pkgs :: <int>, num-versions :: <int>)
  if (~instance?(json, <str-map>))
    invalid-catalog-data-error("Top-level catalog structure must be a map.")
  end;
  // TODO: let metadata = element(json, $catalog-key, default: #f);
  let catalog = make(<catalog>);
  let num-versions = 0;
  for (versions keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-attrs-key)
      let group = json-to-pkg-group(pkg-name, versions[$package-group-attrs-key]);
      for (attrs keyed-by version in versions)
        if (version ~= $package-group-attrs-key)
          add-package(catalog, json-to-package(group, version, attrs));
          num-versions := num-versions + 1;
        end if;
      end for;
    end if;
  end for;
  values(catalog, catalog.packages.size, num-versions)
end;

define function json-to-pkg-group
    (pkg-name :: <str>, pkg-attrs :: <any>) => (d :: <pkg-group>)
  if (~instance?(pkg-attrs, <str-map>))
    invalid-catalog-data-error("Package structure must be a map.")
  end;
  make(<pkg-group>,
       name: pkg-name,
       synopsis: pkg-attrs["synopsis"],
       description: pkg-attrs["description"],
       contact: pkg-attrs["contact"],
       licence-type: pkg-attrs["license-type"],
       keywords: element(pkg-attrs, "keywords", default: #f),
       category: element(pkg-attrs, "category", default: #f))
end;

define function json-to-package
    (group :: <pkg-group>, version :: <str>, pkg-attrs :: <any>) => (p :: <pkg>)
  if (~instance?(pkg-attrs, <str-map>))
    invalid-catalog-data-error("Package version structure must be a map.")
  end;
  make(<pkg>,
       group: group,
       version: json-to-version(version),
       dependencies: map(string-to-dependency, pkg-attrs["deps"]),
       source-url: pkg-attrs["source-url"])
end;

define function json-to-version
    (json :: <any>) => (version :: <version>)
  if (~instance?(json, <str-map>))
    invalid-catalog-data-error("Package structure must be a map.")
  end;
  make(<version>,
       major: json["major"],
       minor: json["minor"],
       patch: json["patch"],
       dependencies: map(string-to-dependency, json["deps"]),
       source-url: json["source-url"])
end;

define constant $package-name-regex :: <regex> = compile-regex("([a-zA-Z][a-zA-Z0-9-]*)");
define constant $version-number-regex :: <regex> = compile-regex("(\\d+)\\.(\\d+)\\.(\\d+)");
define constant $dependency-regex :: <regex>
  = compile-regex(concatenate(regex-pattern($package-name-regex),
                              "/(",
                              regex-pattern($version-number-regex),
                              ")"));

// Parse a dependency spec in the form pkg-name/m.n.p.
define function string-to-dependency
    (input :: <str>) => (d :: <dep>)
  let strings = regex-search-strings($dependency-regex, input);
  if (~strings)
    package-error("Invalid dependency spec, %=, should be in the form pkg/1.2.3", input)
  end;
  let name = strings[1];
  let version = strings[2];
  make(<dep>, name: name, version: string-to-version(version))
end;

define function string-to-version
    (input :: <str>) => (v :: <version>)
  let strings = regex-search-strings($version-number-regex, input);
  make(<version>,
       major: string-to-integer(strings[1]),
       minor: string-to-integer(strings[2]),
       patch: string-to-integer(strings[3]))
end;

define method store-catalog
    (catalog :: <catalog>, store :: <json-file-storage>)
  let packages = table(<istr-map>, $catalog-attrs-key => table(<str-map>, "unused" => "for now"));
  for (pkg in all-packages(catalog))
    let group = pkg.group;
    let versions = element(packages, group.name, default: #f);
    if (~versions)
      versions := table(<str-map>, $package-group-attrs-key => pkg-group-to-json(group));
      packages[group.name] := versions;
    end;
    versions[version-to-string(pkg.version)] := package-to-json(pkg);
  end;
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    encode-json(stream, packages);
  end with-open-file;
end;

define function pkg-group-to-json
    (group :: <pkg-group>) => (json :: <str-map>)
  table(<str-map>,
        "name" => group.name,
        "synopsis" => group.synopsis,
        "description" => group.description,
        "contact" => group.contact,
        "license-type" => group.license-type,
        "keywords" => group.keywords,
        "category" => group.category)
end;

define function package-to-json
    (pkg :: <pkg>) => (json :: <str-map>)
  table(<str-map>,
        "deps" => map(dependency-to-json, pkg.dependencies),
        "source-url" => pkg.source-url)
end;

define function dependency-to-json
    (dep :: <dep>) => (json :: <str-map>)
  table(<str-map>,
        "name" => dep.package-name,
        "version" => dep.version)
end;

define method all-packages
    (cat :: <catalog>) => (pkgs :: <pkg-vec>)
  map-as(<pkg-vec>, identity, cat.packages)
end;

define method add-package
    (cat :: <catalog>, pkg :: <pkg>) => ()
  if (element(cat.packages, pkg.group.name, default: #f))
    package-error("Attempt to add package %=, which already exists in the catalog.",
                  pkg.group.name);
  end;
  cat.packages[pkg.group.name] := pkg;
end;

define method find-package
    (cat :: <catalog>, pkg-name :: <str>, ver :: <version>) => (pkg :: false-or(<pkg>))
  block (return)
    let latest = #f;
    for (pkg keyed-by name in cat.packages)
      if (~reserved-package-name?(name) & string-equal-ic?(name, pkg-name))
        if (ver == $latest)
          if (~latest | pkg.version > latest.version)
            latest := pkg;
          end;
        elseif (ver == pkg.version)
          return(pkg)
        end
      end;
    end for;
    latest
  end block
end method find-package;
          