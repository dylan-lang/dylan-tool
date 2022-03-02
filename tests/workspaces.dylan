module: workspaces-test-suite

define test test-new ()
  let test-dir = test-temp-directory();
  let ws-dir = subdirectory-locator(test-dir, "workspace-1");
  let ws-file = merge-locators(as(<file-locator>, "workspace.json"), ws-dir);
  assert-false(fs/file-exists?(ws-dir));
  let workspace = ws/new("workspace-1", parent-directory: test-dir);
  assert-true(fs/file-exists?(ws-file));
  assert-equal(ws/workspace-directory(workspace), simplify-locator(ws-dir));
end test;

run-test-application();
