Module: package-manager
Synopsis: Package download and installation

define method download-package
    (pkg-name :: <string>, ver :: <version>, dest-dir :: <directory-locator>)
 => (pv :: <package-version>)
  let catalog = load-catalog();
  let url = version.source-url;
  let transport = transport-from-url(url);
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport, url, dest-dir);
end method download-package;

// Download a package version and install it in the standard location
// based on the version number.
// TODO: skip if already installed.
define method install-package
    (pkg-name :: <string>, version :: <version>) => (pkg :: <package>)
  download-package(pkg-name, version, installation-directory(pkg-name, version));
end method install-package;

define function version-string
    (ver :: <version>) => (version :: <string>)
  format-to-string("%d.%d.%d", ver.major, ver.minor, ver,patch)
end;

// Using this constant works around https://github.com/dylan-lang/dylan-mode/issues/27.
define constant $github-url = "https://github.com";

define function transport-from-url
    (url :: <string>) => (transport :: <transport>)
  // TODO: these shouldn't be github-specific.
  if (#t /* temp */ | starts-with?(url, $github-url))
    make(<git-transport>)
  else
    error(make(<package-error>,
               format-string: "Unrecognized package source URL: %=",
               format-arguments: list(url)));
  end
end function transport-from-url;

// TODO: when downloading for installation (as opposed to for
//       development, e.g., into a workspace) just do a shallow clone
//       of a specific branch.  #key shallow?
define method download
    (transport :: <git-transport>, url :: <string>, dest-dir :: <directory-locator>)
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
    error(make(<package-error>,
               format-string: "git clone command (%=) failed with exit code %d.",
               format-arguments: list(command, exit-code)));
  end;
end method download;
