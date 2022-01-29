Module: pacman-test-suite

define test version-=-test ()
  for (item in #[#["latest", "latest", #t],
                 #["1.0.0", "1.0.0", #t],
                 #["0.1.0", "0.2.0", #f]])
    let (s1, s2, want) = apply(values, item);
    let v1 = string-to-version(s1);
    let v2 = string-to-version(s2);
    let got = v1 = v2;
    assert-equal(got, want,
                 format-to-string("got %=, want %= for 'version(%s) = version(%s)'",
                                  got, want, s1, s2));
  end;
end;

define test version-<-test ()
  for (item in #[#["1.0.0",  "2.0.0", #t],  // major
                 #["1.0.0",  "1.0.0", #f],
                 #["2.0.0",  "1.0.0", #f],

                 #["0.1.0",  "0.2.0", #t],  // minor
                 #["1.2.1",  "1.2.1", #f],
                 #["1.2.1",  "1.3.0", #t],

                 #["1.2.3",  "1.2.4", #t],  // patch
                 #["1.2.3",  "1.2.3", #f],
                 #["1.2.4",  "1.2.3", #f]])
    let (s1, s2, want) = apply(values, item);
    let v1 = string-to-version(s1);
    let v2 = string-to-version(s2);
    let got = v1 < v2;
    check-equal(format-to-string("got %=, want %= for 'version(%s) < version(%s)'",
                                 got, want, s1, s2),
                got, want);
  end;
end;
