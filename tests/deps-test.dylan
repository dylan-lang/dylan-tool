Module: pacman-test-suite

// Verify that dep names follow the same rules as package names.
define test test-dep-name-validation ()
  let version = string-to-version("1.0.0");
  for (name in #["", "-x", "0foo", "abc%"])
    assert-signals(<package-error>,
                   make(<dep>, package-name: name, version: version),
                   name);
  end;
  for (name in #["x", "X", "x-y", "x---", "a123", "a.test"])
    assert-no-errors(make(<dep>, package-name: name, version: version), name);
  end;
end test;

define test test-string-to-dep-to-string ()
  assert-equal("p@1.2.3", dep-to-string(string-to-dep("p@1.2.3")));
  assert-equal("p@1.2.0", dep-to-string(string-to-dep("p@1.2")));
  assert-equal("p@branch", dep-to-string(string-to-dep("p@branch")));
  assert-equal("p", dep-to-string(string-to-dep("p")));
  assert-signals(<package-error>, string-to-dep("p@"));
end test;

define test test-dep-= ()
  let dep1 = string-to-dep("p@0.1.2");
  let dep2 = string-to-dep("p@0.1.2");
  let dep3 = string-to-dep("p@0.1.8");
  let dep4 = string-to-dep("x@0.1.2");
  let dep5 = string-to-dep("z@branch");
  assert-true(dep1 = dep2);
  assert-false(dep1 = dep3);
  assert-false(dep1 = dep4);
  assert-false(dep1 = dep5);
end test;

define test test-max-release ()
  let pkg = make-test-package("p", versions: #("1.2.3", "1.2.4", "1.3.3", "2.3.3"));
  let p123 = find-release(pkg, string-to-version("1.2.3"));
  let p124 = find-release(pkg, string-to-version("1.2.4"));
  let p133 = find-release(pkg, string-to-version("1.3.3"));
  let p223 = find-release(pkg, string-to-version("2.2.3"));
  assert-equal(p123, max-release(p123, p123));
  assert-equal(p124, max-release(p123, p124)); // patch different
  assert-equal(p133, max-release(p123, p133)); // minor different
  assert-signals(<dep-conflict>, max-release(p123, p223)); // different major incompatible
end test;

define test test-circular-dependency ()
  // The most direct cyclic relationship. A depends on B and B on A.
  assert-signals(<dep-error>,
                 make-test-catalog(#("A@1.0", "B@1.0"),
                                   #("B@1.0", "A@1.0")));
  // Something with a longer cyclic chain.
  assert-signals(<dep-error>,
                 make-test-catalog(#("A@1.0", "B@1.0"),
                                   #("B@1.0", "C@1.0"),
                                   #("C@1.0", "D@3.4"),
                                   #("D@3.4", "E@2.2"),
                                   #("E@2.2", "A@1.0")));
  // Same as previous but cirularity based on different release of A.  (In other words,
  // this tests that circularities are solely based on the package name, not the release
  // version.)
  assert-signals(<dep-error>,
                 make-test-catalog(#("A@1.0", "B@1.0"),
                                   #("A@2.0", "B@1.0"), // added
                                   #("B@1.0", "C@1.0"),
                                   #("C@1.0", "D@3.4"),
                                   #("D@3.4", "E@2.2"),
                                   #("E@2.2", "A@2.0"))); // changed
end test;

define test test-missing-dependency ()
  // strings@1.0 is listed as a dependency but only 1.1 and 2.0 are listed in the
  // catalog. Although we _could_ choose to use strings@1.1 for this dependency since
  // it's compatible with strings@1.0, it's preferable to disallow dependencies that
  // don't exist in the catalog.
  assert-signals(<dep-error>,
                 make-test-catalog(#("strings@1.1"),
                                   #("strings@2.0"),
                                   #("B@1.0", "strings@1.0"),
                                   #("C@1.0", "strings@2.0"),
                                   #("A@1.0", "B@1.0", "C@1.0")));

  // In this case there's a dependency on package D, which doesn't exist at all.
  assert-signals(<dep-error>,
                 make-test-catalog(#("B@1.0", "D@1.0"),
                                   #("C@1.0", "D@2.0"),
                                   #("A@1.0", "B@1.0", "C@1.0")));
end test;

define test test-dependency-conflict ()
  // A depends on B and C which want different major versions of "strings".
  assert-signals(<dep-conflict>,
                 make-test-catalog(#("strings@1.0"),
                                   #("strings@2.0"),
                                   #("B@1.0", "strings@1.0"),
                                   #("C@1.0", "strings@2.0"),
                                   #("A@1.0", "B@1.0", "C@1.0")));
  // Same as above but it's the minor version that differs, so no conflict.
  assert-no-errors(make-test-catalog(#("strings@1.1"),
                                     #("strings@1.2"),
                                     #("B@1.0", "strings@1.1"),
                                     #("C@1.0", "strings@1.2"),
                                     #("A@1.0", "B@1.0", "C@1.0")));
  // A depends on B and C which want different branches of "strings".
end test;

define test test-minimal-version-selection ()
  local
    method verify (cat, top, expected-deps)
      let dep = string-to-dep(top);
      let release = find-package-release(cat, dep.package-name, dep.dep-version);
      let got-deps = resolve-deps(release, cat);
      let want-deps = map(method (d)
                            let dep = string-to-dep(d);
                            find-package-release(cat, dep.package-name, dep.dep-version);
                          end,
                          expected-deps);
      // Note that resolve-deps does not include the given release in the return value.
      assert-equal(got-deps.size, want-deps.size);
      assert-equal(got-deps.size, intersection(got-deps, want-deps).size);
    end;

  // Example from https://research.swtch.com/vgo-principles#repeatability
  // Both D@1.3 and D@1.4 are depended on. D@1.4 is compatible with D@1.3
  // so 1.4 can be used.
  let cat = make-test-catalog(#("A@1.20", "B@1.3", "C@1.8"),
                              #("B@1.3", "D@1.3"),
                              #("C@1.8", "D@1.4"),
                              #("D@1.3"),
                              #("D@1.4"));
  verify(cat, "A@1.20", #("B@1.3", "C@1.8", "D@1.4"));

  // Example from https://research.swtch.com/vgo-principles#sat-example
  // Same as previous example except we add D@1.5 and make sure that it is NOT chosen
  // since it is no release's minimal dependency. D@1.4 should still be used.
  let cat = make-test-catalog(#("A@1.20", "B@1.3", "C@1.8"),
                              #("B@1.3", "D@1.3"),
                              #("C@1.8", "D@1.4"),
                              #("D@1.3"),
                              #("D@1.4"),
                              #("D@1.5"));
  verify(cat, "A@1.20", #("B@1.3", "C@1.8", "D@1.4"));

  // The "broken" Go example from the same URL as above. Let's make sure ours breaks too.
  // We're not actually doing a build, which is what would break in the example, so we
  // just make sure the deps generated in the example are what we get.
  let cat = make-test-catalog(#("A@1.21", "B@1.4", "C@1.8"),
                              #("B@1.3", "D@1.3"),
                              #("B@1.4", "D@1.6"),
                              #("C@1.8", "D@1.4"),
                              #("C@1.9", "D@1.4"),
                              #("D@1.3"),
                              #("D@1.4"),
                              #("D@1.5"), // Not really needed since Go ignores it.
                              #("D@1.6"));
  verify(cat, "A@1.21", #("B@1.4", "C@1.8", "D@1.6"));
end test;
