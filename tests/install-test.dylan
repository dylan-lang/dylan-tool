Module: pacman-test

define test test-install ()
  // TODO: make a test repo and use instead of mine.
  let pkg = make(<pkg>,
                 name: "json",
                 synopsis: "json synopsis",
                 description: "json description",
                 contact: "zippy@zippy.com",
                 license-type: "MIT",
                 version: string-to-version("1.2.3"),
                 dependencies: make(<dep-vec>, size: 0),
                 // Work around dylan-mode indentation bug...
                 source-url: concat("file:/", "/", "/home/cgay/dylan/repo/json"));
  // TODO: all tests should automatically get their own empty test directory.
  let test-dir = subdirectory-locator(temp-directory(), "test-install");
  delete-directory(subdirectory-locator(test-dir, "pkg"),
                   recursive?: #t);
  environment-variable("DYLAN") := as(<byte-string>, test-dir);
  assert-false(installed?(pkg));
  install-package(pkg);
  assert-true(installed?(pkg));
  let lid-path = merge-locators(as(<file-system-file-locator>,
                                   "pkg/json/1.2.3/src/json.lid"),
                                test-dir);
  assert-true(file-exists?(lid-path));
  let versions = installed-versions(pkg.name);
  test-output("versions = %s", map(version-to-string, versions));
  assert-equal(1, size(versions));
  assert-equal(map-as(<list>, identity, versions), list(pkg.version));
end test;
  
define suite install-suite ()
  test test-install;
end;
