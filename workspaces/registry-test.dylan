Module: dylan-tool-test-suite

// Create a file in the current test's temp directory with the given contents.
// If the file already exists an error is signaled. `filename` is assumed to be
// a relative pathname; if it contains directory structure, subdirectories are
// created. Returns the full, absolute file path as a `<file-locator>`.
//
// TODO(cgay): Wrote this here with the intention to make it part of Testworks
// eventually (possibly under a different name).
define function write-test-file
    (filename :: <pathname>, #key contents :: <string> = "")
 => (full-pathname :: <file-locator>)
  let locator = merge-locators(as(<file-locator>, filename),
                               test-temp-directory());
  ensure-directories-exist(locator);
  with-open-file (stream = locator,
                  direction: #"output", if-exists: #"signal")
    write(stream, contents);
  end;
  locator
end function;

// The low-level LID parsing is done by the file-source-records library so this
// test is mainly concerned with whether parsing the LID: header works.
define test test-parse-lid-file--lid-header ()
  let parent-file
    = write-test-file("parent.lid", contents: "library: foo\nlid: child.lid\n");
  let child-file
    = write-test-file("child.lid", contents: "h1: v1\nh2: v2\n");
  let registry = make(<registry>, root-directory: locator-directory(parent-file));
  let parent-lid = parse-lid-file(registry, parent-file);
  assert-equal(2, parent-lid.lid-data.size);

  let sub-lids = lid-values(parent-lid, $lid-key) | #[];
  assert-equal(1, sub-lids.size);

  let child-lid = sub-lids[0];
  assert-equal(2, child-lid.lid-data.size);
  assert-equal("v1", lid-value(child-lid, #"h1"));
  assert-equal("v2", lid-value(child-lid, #"h2"));
end test;

define test test-source-file-map--basics ()
  let text = "Library: foo\nFiles: library\n  foo.dylan";
  let lid-path = write-test-file("foo.lid", contents: text);
  let directory = locator-directory(lid-path);
  let file-map = source-file-map(directory);
  assert-equal(2, file-map.size);

  // Note that the "library" file intentionally has no ".dylan" extension, and
  // the extension is expected to be added in the map keys.
  for (filename in #("library.dylan", "foo.dylan"))
    let full-locator
      = merge-locators(as(<file-locator>, filename), directory);
    let full-path = as(<string>, full-locator);
    assert-equal(#("foo"),
                 element(file-map, full-path, default: #f),
                 format-to-string("source mapping for %=", full-path));
  end;
end test;

// Test including another LID via the "LID" header. Also exercises the code
// that has to handle LID files that have no "Library" header.
define test test-source-file-map--included-lid ()
  let abc-text  = "Library: abc\nFiles: library\nLID: sub.lid";
  let test-text = "Library: abc-test-suite\nFiles:test-library\nLID: sub.lid";
  let sub-text  = "Files: a\n  b\n  c";

  let lid-path = write-test-file("abc.lid", contents: abc-text);
  write-test-file("abc-test-suite.lid", contents: test-text);
  write-test-file("sub.lid", contents: sub-text);
  let directory = lid-path.locator-directory;
  let file-map = source-file-map(directory);
  assert-equal(5, file-map.size);

  for (item in #(#(#("abc"), "library.dylan"),
                 #(#("abc-test-suite"), "test-library.dylan"),
                 #(#("abc", "abc-test-suite"), "a.dylan", "b.dylan", "c.dylan")))
    let (libraries, #rest filenames) = apply(values, item);
    for (filename in filenames)
      let full-locator
        = merge-locators(as(<file-locator>, filename), directory);
      let full-path = as(<string>, full-locator);
      assert-equal(libraries, element(file-map, full-path, default: #f),
                   format-to-string("source mapping for %=", full-path));
    end;
  end;
end test;
