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

define constant $source-directory-name = "src";

// Directory in which all versions of a package are installed.
define not-inline function package-directory
    (pkg-name :: <string>) => (_ :: <directory-locator>)
  subdirectory-locator(package-manager-directory(), lowercase(pkg-name))
end function;

// Directory in which a specific release is installed.
define not-inline function release-directory
    (release :: <release>) => (_ :: <directory-locator>)
  subdirectory-locator(package-directory(release.package-name),
                       version-to-string(release.release-version))
end function;

// Where the tarball/repo/etc is actually unpacked. We use a subdir of
// the installation directory so there's no conflict with files
// maintained by the package manager itself.
define not-inline function source-directory
    (release :: <release>) => (_ :: <directory-locator>)
  subdirectory-locator(release.release-directory,
                       $source-directory-name)
end function;

define function installed?
    (release :: <release>) => (_ :: <bool>)
  ~directory-empty?(source-directory(release))
end function;

// Download and unpack `release` into `dest-dir` or signal <package-error>
// (for example due to a network or file-system error). Dependencies
// are not downloaded.
define not-inline function download
    (release :: <release>, dest-dir :: <directory-locator>,
     #key update-submodules? :: <bool> = #t)
 => ()
  // Dispatch based on the transport type: git, mercurial, tarball, ...
  %download(package-transport(release), release, dest-dir, update-submodules?);
end function;

define generic %download
    (transport :: <transport>, release :: <release>, dest-dir :: <directory-locator>,
     update-submodules? :: <bool>)
 => ();

define method %download
    (transport :: <git-transport>, release :: <release>, dest-dir :: <directory-locator>,
     update-submodules? :: <bool>)
 => ()
  let branch = "master";
  if (release.release-version ~= $head)
    // By convention, Git releases are tagged with vX.Y.Z, at least for Dylan
    // packages. I don't know how universal this is!
    branch := concat("v", version-to-string(release.release-version));
  end;
  let command = sprintf("git clone%s --quiet --branch=%s -- %s %s",
                        (update-submodules? & " --recurse-submodules") | "",
                        branch, release.release-location, dest-dir);
  let (exit-code, signal-code /* , process, #rest streams */)
    = os/run(command, output: #"null", error: #"null");
  if (exit-code = 0)
    message("Downloaded %s to %s\n", release, dest-dir);
  else
    package-error("git clone command failed with exit code %d. Command: %=",
                  exit-code, command);
  end;
end method;

// Download and install `release` into the standard location.
//
// Parameters:
//   force? - if true, the existing package is removed, if present, and
//     the package is re-installed. This applies transitively to dependencies.
//   deps? - if true , also install dependencies recursively.
// Values:
//   installed? - #t if an installation was performed or #f if the package was
//     already installed and `force?` was #f.
define sealed generic install
    (release :: <release>, #key force?, deps?)
 => (installed? :: <bool>);

define method install
    (release :: <release>, #key force? :: <bool>, deps? :: <bool> = #t)
 => (installed? :: <bool>)
  if (deps?)
    install-deps(release, force?: force?);
  end;
  if (force? & installed?(release))
    verbose-message("Deleting package %s for forced install.\n", release);
    delete-directory(release-directory(release), recursive?: #t);
  end;
  if (installed?(release))
    verbose-message("Package %s is already installed.\n", release);
  else
    download(release, source-directory(release));
    #t
  end
end method;

// Install dependencies of `release`. If `force?` is true, remove and
// re-install all dependencies.  If `update-head?` is true then pull the latest
// updates for any packages that are installed at version $head. `update-head?`
// is redundant (and ignored) when `force?` is true.
define method install-deps
    (release :: <release>, #key force? :: <bool>, update-head? :: <bool>)
  local method install-one (release, _, installed?)
          // TODO: For now update-head? is implemented by forcing force? to
          // true, which will cause the package to be removed and re-installed.
          // Ultimately, it would be better to check whether there's anything
          // new to pull and if update-head? is false, print a warning to the
          // user that they're out-of-date.
          let force? = force? | (update-head? & release.release-version = $head);
          if (force? | ~installed?)
            install(release, force?: force?, deps?: #t);
          end;
        end;
  do-resolved-deps(release, install-one);
end method;

// Apply `fn` to all transitive dependencies of `release` using a
// post-order traversal. `fn` is called with three arguments: the
// package to which the dep was resolved, the dep itself, and a
// boolean indicating whether or not the package is already
// installed. The return value of `fn`, if any, is ignored.
//
// TODO: detect dep circularities
define function do-resolved-deps
    (release :: <release>, fn :: <func>) => ()
  for (dep in release.release-deps)
    let (release, installed?) = resolve(dep);
    do-resolved-deps(release, fn);
    fn(release, dep, installed?);
  end;
end function;

// Resolve a dep to a specific package release. If an installed package meets
// the dependency requirement, it is used, even if there is a newer version in
// the catalog.
//
// TODO: update-dep, a function to install the latest versions rather than
//   using the latest installed version.
//
// TODO: currently this requires that all release deps must be in the
//   catalog. When developing the initial release of a new package that won't
//   work.  Probably should be a flag because in normal use that could lead to
//   non-reproducible environments.
define function resolve
    (dep :: <dep>) => (release :: <release>, installed? :: <bool>)
  let cat = load-catalog();
  let name = dep.package-name;
  block (return)
    let package = find-package(cat, name)
      | package-error("cannot resolve dependency %=, package not found in catalog", dep);
    // See if an installed version works.
    for (version in installed-versions(name, head?: #t)) // newest to oldest
      if (satisfies?(dep, version))
        let release = find-release(package, version);
        if (release)
          return(release, #t);
        end;
      end;
    end;
    // Nope, so find newest matching version in the catalog.
    for (release in sort(package.package-releases.value-sequence,
                         test: method (r1, r2)
                                 r1.release-version > r2.release-version
                               end))
      if (satisfies?(dep, release.release-version))
        return(release, #f);
      end;
    end;
  end block
end function;

// Return all versions of package `package-name` that are installed, sorted
// newest to oldest. If `head?` is true, include the "head" version.
define function installed-versions
    (package-name :: <string>, #key head?) => (versions :: <seq>)
  let package-directory
    = subdirectory-locator(package-manager-directory(),
                           lowercase(package-name));
  let files = block ()
                directory-contents(package-directory)
              exception (<file-system-error>)
                #[]
              end;
  let versions = make(<stretchy-vector>);
  for (file in files)
    if (instance?(file, <directory-locator>))
      let name = locator-name(file);
      if (head? | lowercase(name) ~= $head-name)
        block ()
          add!(versions, string-to-version(name))
        exception (<package-error>)
          // ignore error
        end;
      end;
    end;
  end;
  sort(versions, test: \>)
end function;
