Module: package-manager

// TODO(cgay): replace all calls to error() with the correct error types.

// A datastore backed by a json file on disk. The json encoding is a
// top-level dictionary mapping package names to package objects,
// which are themselves encoded as json dictionaries. Almost all
// fields are required.
define class <json-file-storage> (<storage>)
  constant slot pathname :: <string>, required-init-keyword: pathname:;
end class <json-file-storage>;

// Load a json-encoded catalog from file.
define method load-catalog
    (store :: <json-file-storage>) => (cat :: <catalog>)
  let json = with-open-file(stream = store.pathname,
                            direction: #"input",
                            if-does-not-exist: #f)
               parse-json(read-to-end(stream))
             end;
  json-to-catalog(json | make(<string-table>))
end method load-catalog;

define function json-to-catalog
    (json :: <string-table>) => (cat :: <catalog>)
  let catalog = make(<catalog>);
  for (pkg-dict keyed-by pkg-name in json)
    add-package(catalog, json-to-package(pkg-name, pkg-dict));
  end for;
  catalog
end function json-to-catalog;

define function json-to-package
    (pkg-name :: <string>, json :: <string-table>) => (pkg :: <package>)
  let package = make(<package>,
                     name: pkg-name,
                     synopsis: json["synopsis"],
                     description: json["description"],
                     versions: map(json-to-version, json["versions"]),
                     contact: json["contact"],
                     license: json["license"],
                     keywords: element(json, "keywords", default: #f),
                     category: element(json, "category", default: #f));
  for (version in package.versions)
    version.package := package;
  end;
  package
end function json-to-package;

define function json-to-version
    (json :: <string-table>) => (version :: <version>)
  make(<version>,
       major: json["major"],
       minor: json["minor"],
       patch: json["patch"],
       dependencies: map(string-to-dependency, json["dependencies"]),
       location: json["location"])
end function json-to-version;

define constant $package-name-regex :: <regex> = compile-regex("([a-zA-Z][a-zA-Z0-9-]*)");
define constant $version-number-regex :: <regex> = compile-regex("(\\d+\\.\\d+\\.\\d+)");
define constant $dependency-regex :: <regex>
  = compile-regex(concatenate(regex-pattern($package-name-regex),
                              "/",
                              regex-pattern($version-number-regex)));

// Parse a dependency spec in the form pkg-name/m.n.p.
define function string-to-dependency
    (input :: <string>) => (dep :: <dependency>)
  let strings = regex-search-strings($dependency-regex, input);
  if (~strings)
    error("Invalid dependency spec, %=, should be in the form pkg/1.2.3", input)
  end;
  let name = strings[1];
  let version = strings[2];
  make(<dependency>, name: name, version: version)
end function string-to-dependency;

define method store-catalog
    (catalog :: <catalog>, store :: <json-file-storage>)
  let json = make(<string-table>);
  for (pkg in all-packages(catalog))
    json[pkg.name] := package-to-json(pkg);
  end;
  with-open-file(stream = store.pathname,
                 direction: #"output",
                 if-exists: #"overwrite")
    encode-json(stream, json);
  end with-open-file;
end method store-catalog;

define function package-to-json
    (pkg :: <package>) => (json :: <string-table>)
  table(<string-table>,
        "name" => pkg.name,
        "synopsis" => pkg.synopsis,
        "description" => pkg.description,
        "versions" => map(version-to-json, pkg.versions),
        "contact" => pkg.contact,
        "license" => pkg.license,
        "keywords" => pkg.keywords,
        "category" => pkg.category)
end function package-to-json;

define function version-to-json
    (ver :: <version>) => (json :: <string-table>)
  table(<string-table>,
        "major" => ver.major,
        "minor" => ver.minor,
        "patch" => ver.patch,
        "dependencies" => map(dependency-to-json, ver.dependencies),
        "location" => ver.location)
end function version-to-json;

define function dependency-to-json
    (dep :: <dependency>) => (json :: <string-table>)
  table(<string-table>,
        "name" => dep.package-name,
        "version" => dep.version)
end function dependency-to-json;

define method all-packages
    (cat :: <catalog>) => (pkgs :: <package-list>)
  map-as(<package-list>, identity, cat.packages)
end;

define method add-package
    (cat :: <catalog>, pkg :: <package>) => ()
  if (element(cat.packages, pkg.name, default: #f))
    error(make(<package-error>,
               format-string: "Attempt to add package %=, which already exists in the catalog.",
               format-arguments: list(pkg.name)));
  end;
  cat.packages[pkg.name] := pkg;
end method add-package;
