Module: pacman-test-suite

define test test-find-release ()
  let versions = #("1.0.0", "2.0.0", "2.0.1", "2.1.0", "2.2.2", "3.0.0", "5.9.9");
  let package = make-test-package("p", versions: versions);
  local
    method find (v)
      let rel = find-release(package, string-to-version(v));
      rel & rel.release-version.version-to-string
    end;
  assert-false(find("4.0.0"));
  assert-false(find("3.0.1"));
  assert-false(find("3.1.0"));
  assert-false(find("1.0.1"));

  assert-equal("3.0.0", find("3.0.0"));
  assert-equal("2.1.0", find("2.1.0"));
  assert-equal("2.2.2", find("2.1.1"));
  assert-equal("2.0.0", find("2.0.0"));
  assert-equal("5.9.9", find("5.8.0"));
end test;
