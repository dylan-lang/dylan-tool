Module: pacman-test

define test install-test ()
  let pkg = make(<pkg>,
                 name: "pacman",
                 version: string-to-version("0.0.2"),
                 deps: make(<dep-vec>, size: 0),
                 // Work around dylan-mode indentation bug...
                 location: "https:/" "/github.com/cgay/pacman");
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
                                   "pkg/pacman/0.0.2/src/pacman.lid"),
                                test-dir);
  assert-true(file-exists?(lid-path));
  let versions = installed-versions(pkg.name);
  assert-equal(1, size(versions));
  assert-equal(map-as(<list>, identity, versions), list(pkg.version));
end test;
  
define suite install-suite ()
  test install-test;
end;
