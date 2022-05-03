module: dylan-tool-test-suite

define test test-new ()
  let test-dir = test-temp-directory();
  let ws-dir = subdirectory-locator(test-dir, "workspace-1");
  let ws-file = merge-locators(as(<file-locator>, "workspace.json"), ws-dir);
  assert-false(file-exists?(ws-dir));
  let workspace = new("workspace-1", parent-directory: test-dir);
  assert-true(file-exists?(ws-file));
  assert-equal(workspace-directory(workspace), simplify-locator(ws-dir));
end test;
