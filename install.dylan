Module: %pacman
Synopsis: Package download and installation


define constant $src-dir-name = "src";

// Directory in which all versions of a package are installed.
define function package-directory (pkg-name :: <str>) => (_ :: <directory-locator>)
  subdirectory-locator(package-manager-directory(), lowercase(pkg-name))
end;

// Directory in which a specific version is installed.
define function version-directory (pkg :: <pkg>) => (_ :: <directory-locator>)
  subdirectory-locator(package-directory(pkg.name), version-to-string(pkg.version))
end;

// Where the tarball/repo/etc is actually unpacked. We use a subdir of
// the installation directory so there's no conflict with files
// maintained by the package manager itself.
define function source-directory (pkg :: <pkg>) => (_ :: <directory-locator>)
  subdirectory-locator(version-directory(pkg), $src-dir-name)
end;

define function installed? (pkg :: <pkg>) => (_ :: <bool>)
  ~directory-empty?(source-directory(pkg))
end;

// See the generic in api.dylan.
define method download-package
    (pkg :: <pkg>, dest-dir :: <directory-locator>) => ()
  let url = pkg.source-url;
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  download(transport-from-url(url), url, dest-dir);
end;

// See the generic in api.dylan.
define method install-package
    (pkg :: <pkg>, #key force? :: <bool>, deps? :: <bool> = #t)
 => ()
  if (deps?)
    install-deps(pkg, force?: force?);
  end;
  if (force? & installed?(pkg))
    message("Deleting package %s %s for forced install.\n", pkg.name, pkg.version);
    delete-directory(version-directory(pkg), recursive?: #t);
  end;
  if (~installed?(pkg))
    download-package(pkg, source-directory(pkg));
  else
    // TODO: make %s print <pkg> as "json/1.2.3" and fix everywhere. Same for <dep>.
    message("Package %s %s is already installed.\n", pkg.name, pkg.version);
  end;
end;

// Install all dependencies of pkg recursively.
define function install-deps (pkg :: <pkg>, #key force? :: <bool>)
  for (dep in pkg.dependencies)
    let (pkg, installed?) = resolve(dep);
    if (~installed?)
      install-package(pkg, force?: force?, deps?: #t)
    end;
  end;
end;

// Resolve a dep to a specific version of a package. If an installed
// package meets the dependency requirement, it is used, even if there
// is a newer version in the catalog.
// TODO: update-dep, a function to install the latest packages that satisfy a dep.
define function resolve (dep :: <dep>) => (pkg :: <pkg>, installed? :: <bool>)
  let cat = load-catalog();
  let pkg-name = dep.package-name;
  block (return)
    // See if an installed version works.
    for (version in installed-versions(dep.package-name)) // Sorted newest to oldest.
      if (satisfies?(dep, version))
        let pkg = %find-package(cat, pkg-name, version);
        if (pkg)
          return(pkg, #t);
        end;
      end;
    end;
    // Nope, so find newest matching version in the catalog.
    for (pkg in package-versions(cat, pkg-name))
      if (satisfies?(dep, pkg.version))
        return(pkg, #f);
      end;
    end;
  end block;
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

define function installed-versions (pkg-name :: <str>) => (versions :: <seq>)
  let pkg-dir = subdirectory-locator(package-manager-directory(),
                                     lowercase(pkg-name));
  let files = directory-contents(pkg-dir);
  let versions = make(<stretchy-vector>);
  for (file in files)
    if (instance?(file, <directory-locator>))
      let name = locator-name(file);
      block ()
        add!(versions, string-to-version(name))
      exception (_ :: <package-error>)
      end;
    end;
  end;
  versions
end;
