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
  // Shouldn't need this call to resolve-locator.
  // https://github.com/dylan-lang/testworks/issues/157
  let tmp = resolve-locator(test-temp-directory());
  let ws = merge-locators(as(<file-locator>, $workspace-file-name), tmp);
  let dp = merge-locators(as(<file-locator>, $dylan-package-file-name),
                          subdirectory-locator(tmp, "dp"));
  let bottom = subdirectory-locator(tmp, "dp", "abc", "xyz");
  ensure-directories-exist(bottom);

  // Initially there is no workspace directory.
  let ws-dir = find-workspace-directory(bottom);
  // On github this test runs inside the dylan-tool checkout, so there's
  // a dylan-package.json file outside the test-temp-directory(), hence
  // the prefix check. Succeed as long as the ws-dir is outside tmp.
  assert-true(~ws-dir
                | begin
                    let wdir = as(<string>, ws-dir);
                    let tmps = as(<string>, tmp);
                    ~starts-with?(wdir, tmps);
                  end);

  // dylan-package.json defines the workspace?
  write-test-file(dp, contents: "{}"); // any valid json
  assert-equal(dp.locator-directory, find-workspace-directory(bottom));

  // but workspace.json takes precedence?
  write-test-file(ws, contents: "{}"); // any valid json
  assert-equal(ws.locator-directory, find-workspace-directory(bottom));
end test;
