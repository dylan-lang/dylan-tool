Module: pacman-test

define test install-test ()
  let package = make(<package>, name: "pacman");
  let release = make(<release>,
                     package: package,
                     version: string-to-version("0.0.2"),
                     deps: make(<dep-vector>, size: 0),
                     // Work around dylan-mode indentation bug...
                                  location: "https:/" "/github.com/cgay/pacman");
  package.package-releases[release.release-version.version-to-string]
    := release;
  let test-dir = subdirectory-locator(temp-directory(), "test-install");
  let pkg-dir = subdirectory-locator(test-dir, "pkg");
  if (file-exists?(pkg-dir))
    delete-directory(pkg-dir, recursive?: #t);
  end;
  environment-variable("DYLAN") := as(<byte-string>, test-dir);
  assert-false(installed?(release));
  install(release);
  assert-true(installed?(release));
  let lid-path = merge-locators(as(<file-system-file-locator>,
                                   "pkg/pacman/0.0.2/src/pacman.lid"),
                                test-dir);
  assert-true(file-exists?(lid-path));
  let versions = installed-versions(release.package-name);
  assert-equal(1, size(versions));
  assert-equal(map-as(<list>, identity, versions), list(release.release-version));
end test;
