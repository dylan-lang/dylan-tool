Module: pacman-test

define test test-version-= ()
  for (item in #[#["latest", "latest", #t],
                 #["latest", "0.0.0", #f],
                 #["0.0.0", "0.0.1", #f],
                 #["1.0.0", "1.0.0", #t],
                 #["0.1.0", "0.2.0", #f]])
    let (s1, s2, want) = apply(values, item);
    let v1 = string-to-version(s1);
    let v2 = string-to-version(s2);
    let got = v1 = v2;
    assert-equal(got, want,
                 sprintf("got %=, want %= for 'version(%s) = version(%s)'",
                         got, want, s1, s2));
  end;
end;

define test test-version-< ()
  for (item in #[#["latest", "latest", #f],
                 #["latest", "0.0.0", #f],
                 #["0.0.0", "0.0.1", #t],
                 #["1.0.0", "1.0.0", #f],
                 #["0.1.0", "0.2.0", #t],
                 #["1.2.1", "1.3.0", #t]])
    let (s1, s2, want) = apply(values, item);
    let v1 = string-to-version(s1);
    let v2 = string-to-version(s2);
    let got = v1 < v2;
    assert-equal(got, want,
                 sprintf("got %=, want %= for 'version(%s) < version(%s)'",
                         got, want, s1, s2));
  end;
end;

define test test-dep-name ()
  for (name in #["", "-x", "x_"])
    assert-signals(<package-error>, make(<dep>, package-name: name), name);
  end;
  for (name in #["x", "X", "x-y", "x---"])
    assert-no-errors(make(<dep>, package-name: name));
  end;
end test;

define test test-bad-dep-versions ()
  // The -beta1 bit may be supported in the future, but not now.
  for (vstring in #["a.b.c", "4.5.6-beta1", "2.-3.4",
                    "2", "2.", "2.3", "2.3.", "2.3.4.5"])
    assert-signals(<package-error>, string-to-version(vstring),
                   concat("for vstring = ", vstring));
  end;
  for (vstring in #["0.3.4", "3.4.0", "2018.12.25"])
    assert-no-errors(string-to-version(vstring),
                     concat("for vstring = ", vstring));
  end;
end test;

define test test-good-dep-versions ()
  for (item in list(#("p/*", #f, #f),
                    #("p/9.8.7", "9.8.7", "9.8.7"),
                    #("p/=99.88.77", "99.88.77", "99.88.77"),
                    #("p/>5.6.7", "5.6.7", #f),
                    #("p/<10.0.2", #f, "10.0.2")))
    let (dep-string, minv, maxv) = apply(values, item);
    let got = string-to-dep(dep-string);
    let want = make(<dep>,
                    package-name: "p",
                    min-version: minv & string-to-version(minv),
                    max-version: maxv & string-to-version(maxv));
    assert-equal(got, want,
                 sprintf("for %=, got %=, want %=",
                         dep-string, dep-to-string(got), dep-to-string(want)));
  end;
end test;

define test test-satisfies? ()
  for (item in #(#("p/*", #("1.0.0", "0.0.1"), #t),
                 #("p/1.2.3", #("1.2.3"), #t),
                 #("p/1.2.3", #("1.2.4"), #f),
                 #("p/>5.6.7", #("5.6.7", "5.6.8", "5.7.0", "6.0.1"), #t),
                 #("p/>5.6.7", #("5.6.6", "5.5.8", "4.7.8"), #f)
                 // TODO: more...
                 ))
    let (dstring, vstrings, want) = apply(values, item);
    let dep = string-to-dep(dstring);
    for (vstring in vstrings)
      let version = string-to-version(vstring);
      assert-equal(satisfies?(dep, version), want,
                   sprintf("for dep %s and version %s", dstring, vstring));
    end;
  end;
end;

define suite types-suite ()
  test test-version-=;
  test test-version-<;
  test test-dep-name;
  test test-bad-dep-versions;
  test test-good-dep-versions;
  test test-satisfies?;
end;
