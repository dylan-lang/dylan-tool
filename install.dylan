Module: package-manager
Synopsis: Package download and installation

define method download-version
    (mgr :: <manager>, pkg :: <package>, version :: <version>, dest-dir :: <directory-locator>) => ()
  let url = version.source-url;
  let transport = transport-from-url(url);
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport, url, dest-dir);
end method download-version;

// Download a package version and install it in the standard location
// based on the version number.
define method install-version
    (pkg :: <package>, version :: <version>) => ();
  download-version(pkg, version, installation-directory(mgr, pkg, version-string(version)));
end method install-version;

define function installation-directory
    (pkg-name :: <string>, version :: <string>)
 => (dir :: <directory-locator>)
  subdirectory-locator(root-installation-directory(), pkg-name, version-string)
end;

define function root-installation-directory
    () => (dir :: <directory-locator>)
  subdirectory-locator(dylan-directory(), "pkg")
end;

// The name of the Dylan environment variable.
define constant $dylan :: <byte-string> = "DYLAN";

// Is this a reasonable default?
define constant $default-dylan-directory :: <string> = "/opt/dylan";

// TODO: Dylan implementations should export this.
define function dylan-directory
    () => (dir :: <directory-locator>)
  let dylan = environment-variable($dylan);
  if (dylan)
    as(<directory-locator>, dylan)
  else
    // TODO: use %APPDATA% on Windows
    let home = environment-variable("HOME");
    if (home)
      subdirectory-locator(as(<directory-locator>, home), "dylan")
    else
      as(<directory-locator>, $default-dylan-directory)
    end
  end
end function dylan-directory;

// TODO: when downloading for installation (as opposed to for
// development, e.g., into a workspace) just do a shallow clone of a
// specific branch.  #key shallow?
define method download
    (transport :: <git-transport>, url :: <string>, dest-dir :: <directory-locator>)
 => ()
  // TODO: for git packages, how to handle branches? Require branch
  // "version-1.2.3" to exist?
  let branch = "master";
  // TODO: wrap libgit2
  let (stdin, stdout, stderr)
    = run-application("git", "clone",
                      "--recurse-submodules", "--branch", branch, url, dest-dir);
end method download;