Module: pacman-test-suite

define test test-install ()
  let release = make-test-release("pacman@0.0.2"); // must be in catalog
  let test-dir = subdirectory-locator(test-temp-directory(), "install-test");
  let pkg-dir = subdirectory-locator(test-dir, "pkg");
  environment-variable("DYLAN") := as(<byte-string>, test-dir);
  assert-false(installed?(release));
  install(release);
  assert-true(installed?(release));
  let lid-path = merge-locators(as(<file-locator>, "pkg/pacman/0.0.2/src/pacman.lid"),
                                test-dir);
  assert-true(file-exists?(lid-path));
  let versions = installed-versions(release.package-name);
  assert-equal(1, size(versions));
  assert-equal(map-as(<list>, identity, versions), list(release.release-version));
end test;
