Module: pacman-test

define test test-install ()
    // TODO: make a test repo with specific version branches in it.
    let pkg = make(<pkg>,
		   name: "json",
		   synopsis: "json synopsis",
		   description: "json description",
		   contact: "zippy@zippy.com",
		   license-type: "MIT",
		   version: string-to-version("1.2.3"),
		   dependencies: make(<dep-vec>, size: 0),
		   source-url: "file:///home/cgay/dylan/repo/json");
let dylan-dir = concat(as(<str>, temp-directory()), "test-install/");

environment-variable("DYLAN") := dylan-dir;
install-package(pkg);
let lid-path = concat(dylan-dir, "pkg/json/1.2.3/json/json.lid");
assert-true(file-exists?(lid-path));
end test;
  
