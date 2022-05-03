Module: pacman-test-suite

// This test does an actual install, which requires the git command and network
// access.
define test test-install ()
  // Set the DYLAN environment variable to the test temp directory so that
  // packages will be installed there, in a "pkg" subdir. Because
  // test-temp-directory() uses the DYLAN environment variable we need to save
  // its value beforehand.
  let dir = test-temp-directory();
  let cat = make(<catalog>, directory: dir);
  let package = make-test-package("json",
                                  versions: #("1.0.0"),
                                  catalog: cat);
  let release = find-package-release(cat, "json", $latest);
  let saved-dylan = environment-variable($dylan-env-var);
  block ()
    environment-variable($dylan-env-var) := as(<byte-string>, dir);
    assert-false(installed?(release));
    install(release);
    assert-true(installed?(release));
    let file = as(<file-locator>, "pkg/json/1.0.0/src/json.lid");
    let lid-path = merge-locators(file, dir);
    assert-true(file-exists?(lid-path));
    let versions = installed-versions(release.package-name);
    assert-equal(1, size(versions));
    assert-equal(map-as(<list>, identity, versions), list(release.release-version));
  cleanup
    environment-variable($dylan-env-var) := saved-dylan;
  end;
end test;
