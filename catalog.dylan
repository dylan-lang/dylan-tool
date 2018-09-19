Module: package-manager

/*
json catalog format

* Order within a json object is never guaranteed.
* Package names with leading "__" (double underscore) are reserved.
{
  "__catalog": { ... catalog metadata ... }
  "http": {
    "__package": { ... package descriptor attributes ... }
    "1.0.0": { ... http 1.0.0 attributes ... }
    "1.2.3": { ... http 1.2.3 attributes ... }
  }
  "json": { ... }
  ...
}

*/

// TODO: replace all calls to error() with the correct error types.

// TODO: locking

define constant $catalog-key :: <str> = "__catalog";
define constant $package-key :: <str> = "__package";

// A datastore backed by a json file on disk. The json encoding is a
// top-level dictionary mapping package names to package objects,
// which are themselves encoded as json dictionaries. Almost all
// fields are required.
define class <json-file-storage> (<storage>)
  constant slot pathname :: <str>, required-init-keyword: pathname:;
end;

// TODO: for now we assume the catalog is a local file. should be fetched from some URL.
//define constant $catalog-url :: <uri> = 

define constant $catalog-local-filename :: <str> = "catalog.json";

define function catalog-storage
    () => (s :: <storage>)
  let path = merge-locators($catalog-storage-filename, package-manager-directory());
  make(<json-file-storage>, pathname: path)
end;

// Load a json-encoded catalog from file.
define method load-catalog
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
    message("No package catalog found in %s.", store.pathname);
    make(<str-map>);
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
  for (version-map keyed-by pkg-name in json)
    if (pkg-name ~= $catalog-key)
      let pkg-desc = json-to-package-descriptor(pkg-name, version-map[$package-key]);
      for (attrs keyed-by version in version-map)
        if (version ~= $package-key)
          add-package(catalog, json-to-package(pkg-desc, version, pkg-dict));
          num-versions := num-versions + 1;
        end if;
      end for;
    end if;
  end for;
  values(catalog, catalog.packages.size, num-versions)
end;

define function json-to-package-descriptor
    (pkg-name :: <str>, pkg-attrs :: <any>) => (d :: <package-descriptor>)
  if (~instance?(pkg-attrs, <str-map>))
    invalid-catalog-data-error("Package structure must be a map.")
  end;
  make(<package-descriptor>,
       name: pkg-name,
       synopsis: pkg-attrs["synopsis"],
       description: pkg-attrs["description"],
       contact: pkg-attrs["contact"],
       licence-type: pkg-attrs["license"],
       keywords: element(pkg-attrs, "keywords", default: #f),
       category: element(pkg-attrs, "category", default: #f))
end;

define function json-to-package
    (pkg-desc :: <package-descriptor>, version :: <str>, pkg-attrs :: <any>) => (p :: <pkg>)
  if (~instance?(pkg-attrs, <str-map>))
    invalid-catalog-data-error("Package version structure must be a map.")
  end;
  make(<pkg>,
       descriptor: pkg-desc,
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
    error("Invalid dependency spec, %=, should be in the form pkg/1.2.3", input)
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
  let packages = table(<istr-map>, $catalog-key => table(<str-map>, "unused" => "for now"));
  for (pkg in all-packages(catalog))
    let desc = pkg.descriptor;
    let versions = element(packages, desc.name, default: #f);
    if (~versions)
      versions := table(<str-map>, $package-key => package-descriptor-to-json(desc));
      packages[desc.name] := versions;
    end;
    versions[version-to-string(pkg.version)] := package-to-json(pkg);
  end;
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    encode-json(stream, packages);
  end with-open-file;
end;

define function package-descriptor-to-json
    (desc :: <package-descriptor>) => (json :: <str-map>)
  table(<str-map>,
        "name" => pkg.name,
        "synopsis" => pkg.synopsis,
        "description" => pkg.description,
        "contact" => pkg.contact,
        "license" => pkg.license,
        "keywords" => pkg.keywords,
        "category" => pkg.category)
end;

define function package-to-json
    (pkg :: <pkg>) => (json :: <str-map>)
  table(<str-map>,
        "deps" => map(dependency-to-json, ver.dependencies),
        "source-url" => ver.source-url)
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
    (cat :: <catalog>, pkg :: <package>) => ()
  if (element(cat.packages, pkg.name, default: #f))
    error(make(<package-error>,
               format-string: "Attempt to add package %=, which already exists in the catalog.",
               format-arguments: list(pkg.name)));
  end;
  cat.packages[pkg.name] := pkg;
end;
