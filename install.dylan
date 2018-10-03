Module: %pacman
Synopsis: Package download and installation


define constant $src-dir-name = "src";

define function installation-directory (pkg :: <pkg>) => (_ :: <directory-locator>)
  subdirectory-locator(package-manager-directory(),
                       as-lowercase(pkg.name),
                       version-to-string(pkg.version))
end;

// Where the tarball/repo/etc is actually unpacked. We use a subdir of
// the installation directory so there's no conflict with files
// maintained by the package manager.
define function source-directory (pkg :: <pkg>) => (_ :: <directory-locator>)
  subdirectory-locator(installation-directory(pkg), $src-dir-name)
end;

define function installed? (pkg :: <pkg>) => (_ :: <bool>)
  ~directory-empty?(source-directory(pkg))
end;

define method download-package
    (pkg :: <pkg>, dest-dir :: <directory-locator>) => ()
  let url = pkg.source-url;
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport-from-url(url), url, dest-dir);
end;

// Download a package and install it in the standard location based on
// the version number.
define method install-package
    (pkg :: <pkg>, #key force? :: <bool>) => ()
  if (force? | ~installed?(pkg))
    download-package(pkg, source-directory(pkg));
  else
    // TODO: make <pkg> print as "json/1.2.3".
    message("Package %s is already installed.", pkg);
  end;
end;

// Using this constant works around https://github.com/dylan-lang/dylan-mode/issues/27.
define constant $github-url = "https://github.com";

// For now I'm assuming file://... is git because it doesn't seem to
// allow a trailing ".git" in the URL to disambiguate. Not sure if
// Mercurial or others can use "file:" URLs.
// TODO:
//   git@<domain>:org/repo.git or
//   https://<domain>/org/repo.git or
//   ssh://blah-de-blah/repo.git 
//define constant $git-transport-re = re/compile(file://

define function transport-from-url
    (url :: <str>) => (transport :: <transport>)
  if (#t /* TODO */ | starts-with?(url, $github-url))
    make(<git-transport>)
  else
    package-error("unrecognized package source URL: %=", url);
  end
end;

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
  let command = sprintf("git clone --recurse-submodules --branch=%s -- %s %s",
			branch, url, as(<str>, dest-dir));
  let (exit-code, #rest more)
    = os/run(command,
             output: "/tmp/git-clone-stdout.log", // temp
             error: "/tmp/git-clone-stderr.log",  // temp
             if-output-exists: #"append",
             if-error-exists: #"append");
  if (exit-code ~= 0)
    package-error("git clone command (%=) failed with exit code %d.",
                  command, exit-code);
  end;
end;
