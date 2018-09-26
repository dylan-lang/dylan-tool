Module: %pacman
Synopsis: Package download and installation


define function installation-directory
    (pkg-name :: <str>, ver :: <version>) => (dir :: <directory-locator>)
  subdirectory-locator(package-manager-directory(),
                       as-lowercase(pkg-name),
                       version-to-string(ver))
end;

define method download-package
    (pkg-name :: <str>, ver :: <version>, dest-dir :: <directory-locator>) => (p :: <pkg>)
  let catalog = load-catalog();
  let pkg-name :: <str> = pkg-name;
  let pkg = find-package(catalog, pkg-name, ver);
  if (~pkg)
    package-error("package not found: %s/%s", pkg-name, version-to-string(ver));
  end;
  let url = pkg.source-url;
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport-from-url(url), url, dest-dir);
  pkg
end method download-package;

// Download a package and install it in the standard location
// based on the version number.
// TODO: skip if already installed.
define method install-package
    (pkg-name :: <str>, ver :: <version>) => (p :: <pkg>)
  download-package(pkg-name, ver, installation-directory(pkg-name, ver));
end method install-package;

// Using this constant works around https://github.com/dylan-lang/dylan-mode/issues/27.
define constant $github-url = "https://github.com";

define function transport-from-url
    (url :: <str>) => (transport :: <transport>)
  // TODO: these shouldn't be github-specific.
  if (#t /* temp */ | starts-with?(url, $github-url))
    make(<git-transport>)
  else
    package-error("unrecognized package source URL: %=", url);
  end
end function transport-from-url;

// TODO: when downloading for installation (as opposed to for
//       development, e.g., into a workspace) just do a shallow clone
//       of a specific branch.  #key shallow?
define method download
    (transport :: <git-transport>, url :: <str>, dest-dir :: <directory-locator>)
 => ()
  // TODO: for git packages, how to handle branches? Require branch
  // "version-1.2.3" to exist?
  let branch = "master";
  // TODO: wrap libgit2
  let command = list("git", "clone", "--recurse-submodules",
                     "--branch", branch, url, dest-dir);
  let (exit-code, #rest more)
    = run-application(command,
                      output: "/tmp/git-clone-stdout.log", // temp
                      error: "/tmp/git-clone-stderr.log",  // temp
                      if-output-exists: #"append",
                      if-error-exists: #"append");
  if (exit-code ~= 0)
    package-error("git clone command (%=) failed with exit code %d.", command, exit-code);
  end;
end method download;
