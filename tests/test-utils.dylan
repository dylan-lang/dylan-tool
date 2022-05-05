Module: dylan-tool-test-suite

// Make a package with a release for each version in `versions`, each release
// having the given deps. If catalog is provided, the package and releases are
// fetched from it if they exist and added to it if they don't.
define function make-test-package
    (name, #key versions, deps, dev-deps, catalog) => (p :: <package>)
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
  let deps = as(<dep-vector>, map(string-to-dep, deps | #()));
  let dev-deps = as(<dep-vector>, map(string-to-dep, dev-deps | #()));
  for (v in versions)
    let version = string-to-version(v);
    let release = find-release(package, version);
    if (~release)
      add-release(package,
                  make(<release>,
                       package: package,
                       version: version,
                       deps: deps,
                       dev-deps: dev-deps,
                       url: format-to-string("https://github.com/dylan-lang/%s", name),
                       license: "MIT",
                       license-url: "https://github.com/dylan-lang/package/LICENSE"));
    end;
  end;
  package
end function;

// Make a catalog from a set of specs. Each spec is a sequence in this form:
//   #(package-name-and-version, deps, dev-deps)
// Example:
//   #("P@1.2", #("D@3.4.5"), #("DD@9.9", "T@4.0")) means create package P and a
//   release for P@1.2 with dep D@3.4.5 and dev deps DD@9.9 and T@4.0.
// Example:
//   #("P@1.2", #("D@3.4.5")) means to make the same package as above but with no
//   dev deps.
define function make-test-catalog
    (#rest package-specs) => (c :: <catalog>)
  let catalog = make(<catalog>, directory: test-temp-directory());
  for (spec in package-specs)
    let (name, deps, dev-deps) = apply(values, spec);
    let dep = string-to-dep(name);
    make-test-package(dep.package-name,
                      versions: list(version-to-string(dep.dep-version)),
                      deps: deps,
                      dev-deps: dev-deps,
                      catalog: catalog);
  end;
  validate-catalog(catalog, cached?: #t);
  catalog
end function;
