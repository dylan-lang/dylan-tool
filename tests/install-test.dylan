Module: pacman-test

define test test-install ()
  // TODO: make a test repo with specific version branches in it.
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
  install-package(pkg);
  let lid-path = merge-locators(as(<file-system-file-locator>,
                                   "pkg/json/1.2.3/json.lid"),
                                test-dir);
  test-output("\nlid-path = %s\n", as(<str>, lid-path));
  assert-true(file-exists?(lid-path));
end test;
  
