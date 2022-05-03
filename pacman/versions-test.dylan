Module: dylan-tool-test-suite

define test test-string-to-version ()
  for (vstring in #["4.5.6-beta1", // may be supported in future
                    "2.-3.4",
                    "2",           // need at least major.minor
                    "2.", "2.3.", "2.3.4.5",
                    "0.0.0"])      // must have a non-zero component
    assert-signals(<package-error>, string-to-version(vstring),
                   "for vstring = %=", vstring);
  end;
  for (item in list(list("0.0.1", <semantic-version>),
                    list("3.4.0", <semantic-version>),
                    list("2018.12.25", <semantic-version>),
                    list("LAtest", <latest>),
                    list("master", <branch-version>),
                    list("a.b.c", <branch-version>)))
    let (vstring, class) = apply(values, item);
    assert-no-errors(string-to-version(vstring),
                     "for vstring = %=", vstring);
    assert-equal(class, object-class(string-to-version(vstring)),
                 "for vstring = %=", vstring);
  end;
end test;

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
