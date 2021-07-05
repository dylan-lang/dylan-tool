Module: pacman-test

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
