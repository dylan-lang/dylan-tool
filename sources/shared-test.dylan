Module: dylan-tool-test-suite


define function capture-standard-output
    (fun, #rest args) => (output :: <string>)
  with-output-to-string (s)
    dynamic-bind (*standard-output* = s)
      apply(fun, args)
    end
  end
end function;

define test test-note ()
  assert-equal("abc\n", capture-standard-output(note, "abc"));
end test;

define test test-warn ()
  assert-equal("WARNING: abc\n", capture-standard-output(warn, "abc"));
end test;

define test test-debug ()
  *debug?* := #f;
  assert-equal("", capture-standard-output(debug, "abc"));
  block ()
    *debug?* := #t;
    assert-equal("abc\n", capture-standard-output(debug, "abc"));
  cleanup
    *debug?* := #f;
  end;
end test;

define test test-verbose ()
  *verbose?* := #f;
  assert-equal("", capture-standard-output(verbose, "abc"));
  block ()
    *verbose?* := #t;
    assert-equal("abc\n", capture-standard-output(verbose, "abc"));
  cleanup
    *verbose?* := #f;
  end;
end test;

define test test-trace ()
  *debug?* := #f;
  *verbose?* := #f;
  assert-equal("", capture-standard-output(trace, "abc"));
  block ()
    *debug?* := #t;
    *verbose?* := #f;
    assert-equal("", capture-standard-output(trace, "abc"));
    *debug?* := #f;
    *verbose?* := #t;
    assert-equal("", capture-standard-output(trace, "abc"));
    *debug?* := #t;
    *verbose?* := #t;
    assert-equal("abc\n", capture-standard-output(trace, "abc"));
  cleanup
    *debug?* := #f;
    *verbose?* := #f;
  end;
end test;
