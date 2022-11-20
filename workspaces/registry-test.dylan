Module: dylan-tool-test-suite

// The low-level LID parsing is done by the file-source-records library so this
// test is mainly concerned with whether parsing the LID: header works.
define test test-parse-lid-file/lid-header ()
  let parent-text = "library: foo\nlid: child.lid\n";
  let child-text = "h1: v1\nh2: v2\n";
  let parent-file = merge-locators(as(<file-locator>, "parent.lid"),
                                   test-temp-directory());
  let child-file = merge-locators(as(<file-locator>, "child.lid"),
                                  test-temp-directory());
  with-open-file (stream = parent-file,
                  direction: #"output", if-exists: #"replace")
    write(stream, parent-text);
  end;
  with-open-file (stream = parent-file,
                  direction: #"output", if-exists: #"replace")
    write(stream, parent-text);
  end;

  let registry = make(<registry>, root-directory: test-temp-directory());
  let parent-lid = parse-lid-file(registry, parent-file);
  assert-equal(2, parent-lid.lid-data.size);

  let sub-lids = lid-values(parent-lid, $lid-key) | #[];
  assert-equal(1, sub-lids.size);

  let child-lid = sub-lids[0];
  assert-equal(2, child-lid.lid-data.size);
  assert-equal(#"v1", lid-value(child-lid, #"h1"));
  assert-equal(#"v2", lid-value(child-lid, #"h2"));
end test;
