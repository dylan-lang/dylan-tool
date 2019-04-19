module: workspaces-tests

define test test-new ()
  let test-dir = test-temp-directory();
  let ws-dir = subdirectory-locator(test-dir, "workspace-1");
  let ws-file = merge-locators(as(<file-locator>, "workspace.json"), ws-dir);
  assert-false(fs/file-exists?(ws-dir));
  ws/new("workspace-1", #["pkg-1", "pkg-2"], parent-directory: test-dir);
  assert-true(fs/file-exists?(ws-file));

  let dict = fs/with-open-file(stream = ws-file)
               json/parse(stream)
             end;
  assert-true(dict["active"]);
  assert-true(dict["active"]["pkg-1"]);
  assert-true(dict["active"]["pkg-2"]);
end test;

run-test-application();
