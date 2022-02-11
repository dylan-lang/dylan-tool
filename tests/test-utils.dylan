Module: pacman-test-suite

// Make a package with a release for each version in `versions`, each release
// having the given deps. If catalog is provided, the package and releases are
// fetched from it if they exist and added to it if they don't.
define function make-test-package
    (name, #key versions, deps = #(), catalog) => (p :: <package>)
  let package = catalog & cached-package(catalog, name);
  if (~package)
    package := make(<package>,
                    name: name,
                    description: "description",
                    contact: "a@b.c",
                    category: "category",
                    keywords: #["key1", "key2"]);
    catalog & cache-package(catalog, package);
  end;
  let deps = as(<dep-vector>, map(string-to-dep, deps));
  for (v in versions)
    let version = string-to-version(v);
    let release = find-release(package, version);
    if (~release)
      add-release(package,
                  make(<release>,
                       package: package,
                       version: version,
                       deps: deps,
                       url: format-to-string("https://github.com/dylan-lang/%s", name),
                       license: "MIT",
                       license-url: "https://github.com/dylan-lang/package/LICENSE"));
    end;
  end;
  package
end function;

// Make a catalog from a set of specs, each of which is a list of dep strings
// like #("p@1.2", "d@3.4.5"). The first string in each spec is taken as a new
// package to create, with one release, and the remaining strings, if any, are
// taken as dependencies for that release.
define function make-test-catalog
    (#rest package-specs) => (c :: <catalog>)
  let catalog = make(<catalog>, directory: test-temp-directory());
  for (spec in package-specs)
    let dep = string-to-dep(spec[0]);
    make-test-package(dep.package-name,
                      versions: list(version-to-string(dep.dep-version)),
                      deps: copy-sequence(spec, start: 1),
                      catalog: catalog);
  end;
  validate-catalog(catalog, cached?: #t);
  catalog
end function;
