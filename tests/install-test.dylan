Module: pacman-test

define test install-test ()
  // TODO: make a test repo and use instead of mine.
  let pkg = make(<pkg>,
                 name: "json",
                 version: string-to-version("1.2.3"),
                 deps: make(<dep-vec>, size: 0),
                 // Work around dylan-mode indentation bug...
                 location: concat("file:/", "/", "/home/cgay/dylan/repo/json"));
  let test-dir = subdirectory-locator(temp-directory(), "test-install");
  let pkg-dir = subdirectory-locator(test-dir, "pkg");
  if (file-exists?(pkg-dir))
    delete-directory(pkg-dir, recursive?: #t);
  end;
  environment-variable("DYLAN") := as(<byte-string>, test-dir);
  assert-false(installed?(pkg));
  install(pkg);
  assert-true(installed?(pkg));
  let lid-path = merge-locators(as(<file-system-file-locator>,
                                   "pkg/json/1.2.3/src/json.lid"),
                                test-dir);
  assert-true(file-exists?(lid-path));
  let versions = installed-versions(pkg.name);
  assert-equal(1, size(versions));
  assert-equal(map-as(<list>, identity, versions), list(pkg.version));
end test;
  
define suite install-suite ()
  test install-test;
end;
