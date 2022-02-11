Module: pacman-test-suite

define constant $http-package
  = make-test-package("http",
                      versions: #("1.2.2", "1.2.3"),
                      deps: #("json@1.2.3"));

define constant $json-package
  = make-test-package("json",
                      versions: #("1.2.2", "1.2.3"));

define test test-write-and-restore-package ()
  let dir = test-temp-directory();
  let cat = make(<catalog>, directory: dir);
  write-package-file(cat, $http-package);
  write-package-file(cat, $json-package);
  let http = load-package(cat, "http");
  let json = load-package(cat, "json");
  assert-equal(2, size(catalog-package-cache(cat)));
  // This depends on being able to resolve the json@1.2.3 dep in the http
  // package.
  assert-no-errors(validate-catalog(cat));
end test;

define test test-find-latest-version ()
  let dir = test-temp-directory();
  let cat = make(<catalog>, directory: dir);
  write-package-file(cat, $http-package);
  write-package-file(cat, $json-package);
  let json = find-package-release(cat, "json", $latest);
  assert-true(json);
  assert-equal("1.2.3", version-to-string(json.release-version));
end test;
