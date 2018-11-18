Module: %pacman
Synopsis: Package download and installation

// TODO:
//  * wrap libgit2 instead of shelling out to git.
//  * ^^ or not. Perhaps it doesn't really make sense to use arbitrary
//    URLs as the package location. That likely requires every user to
//    have access credentials for all the servers those URLs point to.
//    It's probably necessary to have a single location (with mirrors)
//    into which we stuff a tarball or zip file. What do other package
//    managers do?

define constant $src-dir-name = "src";

// Directory in which all versions of a package are installed.
define function package-directory (pkg-name :: <string>) => (_ :: <directory-locator>)
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

// Download and unpack `pkg` into `dest-dir` or signal <package-error>
// (for example due to a network or file-system error). Dependencies
// are not downloaded.
define function download
    (pkg :: <pkg>, dest-dir :: <directory-locator>) => ()
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  %download(package-transport(pkg), pkg.location, dest-dir);
end;

define generic %download
    (transport :: <transport>, location :: <string>, dest-dir :: <directory-locator>);

define method %download
    (transport :: <git-transport>, location :: <string>, dest-dir :: <directory-locator>)
 => ()
  // TODO: add --quiet, once debugged
  let command = sprintf("git clone --recurse-submodules --branch=%s -- %s %s",
                        transport.branch, location, dest-dir);
  let (exit-code, #rest more)
    = os/run(command,
             output: "/tmp/git-clone-stdout.log", // temp
             error: "/tmp/git-clone-stderr.log",  // temp
             if-output-exists: #"append",
             if-error-exists: #"append");
  if (exit-code ~= 0)
    package-error("git clone command failed with exit code %d. Command: %=",
                  exit-code, command);
  end;
end;

define function package-transport
    (pkg :: <pkg>) => (transport :: <transport>)
  // TODO: don't assume github. If it's not general enough to detect
  // which transport to use based on the package location we might
  // have to specify the transport explicitly in the catalog and
  // package files.
  if (find-substring(pkg.location, "github")
        | starts-with?(pkg.location, "file:/" "/")) // work around indentation bug
    let branch = "master";
    if (pkg.version ~= $head)
      branch := sprintf("v%s", version-to-string(pkg.version));
    end;
    make(<git-transport>, branch: branch)
  else
    package-error("unrecognized package source URL: %=", pkg.location);
  end
end;

// Download and install `pkg` into the standard location. If `force?`
// is true the existing package is removed, if present, and the
// package is re-installed.  If `deps?` is true , also install
// dependencies recursively. The `force?` argument applies to
// dependency installations also, if any. Returns #t if an
// installation was performed or #f if the package was already
// installed and `force?` was #f.
define sealed generic install
  (pkg :: <pkg>, #key force?, deps?) => (installed? :: <bool>);

define method install
    (pkg :: <pkg>, #key force? :: <bool>, deps? :: <bool> = #t)
 => (installed? :: <bool>)
  if (deps?)
    install-deps(pkg, force?: force?);
  end;
  if (force? & installed?(pkg))
    message("Deleting package %s for forced install.\n", pkg);
    delete-directory(version-directory(pkg), recursive?: #t);
  end;
  if (installed?(pkg))
    message("Package %s is already installed.\n", pkg);
  else
    download(pkg, source-directory(pkg));
    #t
  end
end;

define method install-deps (pkg :: <pkg>, #key force? :: <bool>)
  local method doit (p, _, installed?)
          ~installed? & install(p, force?: force?, deps?: #t)
        end;
  do-resolved-deps(pkg, doit);
end;

// Apply `fn` to all transitive dependencies of `pkg` using a
// post-order traversal. `fn` is called with three arguments: the
// package to which the dep was resolved, the dep itself, and a
// boolean indicating whether or not the package is already
// installed. The return value of `fn`, if any, is ignored.
//
// TODO: detect dep circularities
define function do-resolved-deps (pkg :: <pkg>, fn :: <func>) => ()
  for (dep in pkg.deps)
    let (pkg, installed?) = resolve(dep);
    do-resolved-deps(pkg, fn);
    fn(pkg, dep, installed?);
  end;
end;

// Resolve a dep to a specific version of a package. If an installed
// package meets the dependency requirement, it is used, even if there
// is a newer version in the catalog.
// TODO: update-dep, a function to install the latest versions rather
//       than using the latest installed version.
define function resolve (dep :: <dep>) => (pkg :: <pkg>, installed? :: <bool>)
  let cat = load-catalog();
  let pkg-name = dep.package-name;
  block (return)
    // See if an installed version works.
    for (version in installed-versions(dep.package-name, head?: #t)) // newest to oldest
      if (satisfies?(dep, version))
        let pkg = find-package(cat, pkg-name, version);
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

// Return all versions of `pkg-name` that are installed, sorted newest
// to oldest. If `head?` is true, include the "head" version.
define function installed-versions
    (pkg-name :: <string>, #key head?) => (versions :: <seq>)
  let pkg-dir = subdirectory-locator(package-manager-directory(),
                                     lowercase(pkg-name));
  let files = block ()
                directory-contents(pkg-dir)
              exception (e :: <file-system-error>)
                #[]
              end;
  let versions = make(<stretchy-vector>);
  for (file in files)
    if (instance?(file, <directory-locator>))
      let name = locator-name(file);
      if (head? | lowercase(name) ~= $head-name)
        block ()
          add!(versions, string-to-version(name))
        exception (_ :: <package-error>)
          // ignore error
        end;
      end;
    end;
  end;
  sort(versions, test: \>)
end;
