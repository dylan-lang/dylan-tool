module: dylan-tool-test-suite

define test test-new ()
  let test-dir = test-temp-directory();
  let ws-dir = subdirectory-locator(test-dir, "workspace-1");
  let ws-file = merge-locators(as(<file-locator>, $workspace-file-name), ws-dir);
  assert-false(file-exists?(ws-dir));
  let workspace = new("workspace-1", parent-directory: test-dir);
  assert-true(file-exists?(ws-file));
  assert-equal(workspace-directory(workspace), simplify-locator(ws-dir));
end test;

define test test-find-workspace-directory ()
  let test-dir = test-temp-directory();
  let ws-file = merge-locators(as(<file-locator>, $workspace-file-name), test-dir);
  let dp-file = merge-locators(as(<file-locator>, $dylan-package-file-name),
                               subdirectory-locator(test-dir, "dp"));
  let reg-dir = subdirectory-locator(test-dir, "dp", "abc", "registry");
  let start = subdirectory-locator(reg-dir, "start");
  // Create files starting at the deepest level and check after each.
  ensure-directories-exist(start);
  assert-equal(reg-dir.locator-directory, find-workspace-directory(start));
  write-test-file(dp-file, contents: "{}"); // any valid json
  assert-equal(dp-file.locator-directory, find-workspace-directory(start));
  write-test-file(ws-file, contents: "{}"); // any valid json
  assert-equal(ws-file.locator-directory, find-workspace-directory(start));
end test;
