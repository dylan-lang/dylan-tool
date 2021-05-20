Module: pacman-test

// Make a <release> from a dependency spec like "pkg@1.2.3". If a catalog is given then
// the release is added to the package with the same name in the catalog, if
// any. Otherwise a new package is created. `deps` is also a sequence of dep specs for
// the release.
define function make-test-release
    (dep-spec :: <string>, #key catalog, deps = #[]) => (release :: <release>)
  let dep = string-to-dep(dep-spec);
  let name = dep.package-name;
  let pkg = catalog & find-package(catalog, name);
  let package = pkg | make(<package>,
                           name: name,
                           summary: "summary",
                           description: "description",
                           contact: "contact@contact",
                           license-type: "license-type",
                           category: "category",
                           releases: make(<stretchy-vector>));
  let rel = catalog & find-package-release(catalog, name, dep.dep-version);
  let release
    = rel | make(<release>,
                 package: package,
                 version: dep.dep-version,
                 deps: map-as(<dep-vector>, string-to-dep, deps),
                 // test-install depends on this being a real repo.
                 location: format-to-string("https://github.com/cgay/%s", name));
  add!(package.package-releases, release);
  sort!(package.package-releases, test: \>);
  if (catalog & ~pkg)
    // This is a new package; add it to the catalog.
    catalog.all-packages[name] := package;
  end;
  release
end function;

// Make a catalog from a list of package specs. Each "spec" is a list like
// #("p@1.2.3", "d@1.2.3", ...) where the first element is a release to add
// to the catalog and the remaining elements are dependencies for that release.
//
define function make-test-catalog
    (#rest package-specs) => (c :: <catalog>)
  let catalog = make(<catalog>,
                     packages: make(<istring-table>));
  for (package-spec in package-specs)
    // Mutate catalog...
    make-test-release(head(package-spec), catalog: catalog, deps: tail(package-spec));
  end;
  validate-catalog(catalog);
  catalog
end function;
