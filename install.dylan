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
  // TODO(cgay): Use GitHub et al's HTTP API instead, so users needn't have git, hg, etc
  // installed. For reference, curl -L https://github.com/dylan-lang/testworks/archive/refs/tags/v1.1.0.tar.gz --output testworks-v1.1.0.tar.gz
  let branch = release.release-version.version-branch;
  let command
    = format-to-string("git clone%s --quiet --branch=%s -- %s %s",
                       (update-submodules? & " --recurse-submodules") | "",
                       branch, release.release-location, dest-dir);
  let (exit-code, signal-code /* , process, #rest streams */)
    = os/run(command, output: #"null", error: #"null");
  if (exit-code = 0)
    log-info("Downloaded %s to %s", release, dest-dir);
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
//   deps? - if true, also install dependencies recursively.
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
    log-trace("Deleting package %s for forced install.", release);
    delete-directory(release-directory(release), recursive?: #t);
  end;
  if (installed?(release))
    log-trace("Package %s is already installed.", release);
  else
    download(release, source-directory(release));
    #t
  end
end method;

// Install dependencies of `release`. If `force?` is true, remove and
// re-install all dependencies.
define method install-deps
    (release :: <release>, #key force? :: <bool>)
  let cat = load-catalog();
  // TODO(cgay): pass correct `active:` arg.
  for (rel in resolve-deps(release, cat))
    if (force? | ~installed?)
      install(rel, force?: force?, deps?: #t);
    end;
  end;
end method;

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
