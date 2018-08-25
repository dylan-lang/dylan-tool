Module: package-manager
Synopsis: Package download and installation

define method download-version
    (pkg :: <package>, version :: <version>, dest-dir :: <directory-locator>) => ()
  let url = version.source-url;
  let transport = transport-from-url(url);
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport, url, dest-dir);
end method download-version;

// Download a package version and install it in the standard location
// based on the version number.
define method install-version
    (pkg :: <package>, version :: <version>) => ();
  download-version(pkg, version, installation-directory(pkg, version-string(version)));
end method install-version;

define function version-string
    (ver :: <version>) => (version :: <string>)
  format-to-string("%d.%d.%d", ver.major, ver.minor, ver,patch)
end;

define function installation-directory
    (pkg-name :: <string>, version :: <string>)
 => (dir :: <directory-locator>)
  subdirectory-locator(root-installation-directory(), pkg-name, version)
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

// https://github.com/dylan-lang/dylan-mode/issues/27
define constant $github-https = "https://github.com";

define function transport-from-url
    (url :: <string>) => (transport :: <transport>)
  // TODO: these shouldn't be github-specific.
  if (starts-with?(url, $github-https))
    make(<git-transport>)
  else
    error(make(<package-error>,
               format-string: "Unrecognized package source URL: %=",
               format-arguments: list(url)));
  end
end function transport-from-url;

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