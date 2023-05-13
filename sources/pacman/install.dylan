Module: %pacman
Synopsis: Package download and installation


define constant $source-directory-name = "src";

// Directory in which to find or install packages. This depends on the value of
// *package-manager-directory*, which may be dynamically bound.
define generic package-directory
    (package :: <object>) => (directory :: <directory-locator>);

define method package-directory
    (pkg-name :: <string>) => (directory :: <directory-locator>)
  subdirectory-locator(package-manager-directory(), lowercase(pkg-name))
end method;

define method package-directory
    (package :: type-union(<package>, <release>))
 => (directory :: <directory-locator>)
  package-directory(package-name(package))
end method;

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
  ~fs/directory-empty?(source-directory(release))
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
                       branch, release.release-url, dest-dir);
  let exit-code = os/run-application(command, output: #"null", error: #"null");
  if (exit-code = 0)
    note("Downloaded %s to %s", release, dest-dir);
  else
    package-error("git clone command failed with exit code %d. Command: %=",
                  exit-code, command);
  end;
end method;

// Make sure the "current" link from `release`s package directory to
// `target-dir` is up to date.
define function ensure-current-link
    (release :: <release>, target-dir :: <directory-locator>) => ()
  let link-source = merge-locators(as(<file-locator>, "current"),
                                   package-directory(release-package(release)));
  // Use file-type instead of file-exists? because the latter would follow the link.
  // After https://github.com/dylan-lang/opendylan/pull/1484 is in an OD release
  // (i.e., post 2022.1) this can use file-exists?(link-source, follow-links?: #f).
  let exists? = block ()
                  fs/file-type(link-source)
                exception (fs/<file-system-error>)
                  #f
                end;
  let target = as(<string>, release-directory(release));
  if (ends-with?(target, "/") | ends-with?(target, "\\"))
    target := copy-sequence(target, end: target.size - 1);
  end;
  let existing-target = exists? & fs/link-target(link-source);
  if (exists? & (target ~= as(<string>, existing-target)))
    debug("Deleting %s", link-source);
    fs/delete-file(link-source);
    exists? := #f;
  end;
  if (~exists?)
    debug("Creating symlink %s -> %s", link-source, target);
    create-symbolic-link(target, link-source);
  end;
end function;

// TODO(cgay): TEMPORARY -- Need to add create-symbolic-link to the system library
// but for now this allows me to move forward.
define function create-symbolic-link
    (target :: fs/<pathname>, link-name :: fs/<pathname>)
  let command
    = if (os/$os-name == #"win32")
        vector("mklink", "/D", link-name, target) // untested
      else
        vector("/bin/ln", "--symbolic",
               as(<byte-string>, target),
               as(<byte-string>, link-name))
      end;
  let exit-code
    = os/run-application(command, under-shell?: #f, output: #"null", error: #"null");
  if (exit-code ~= 0)
    package-error("failed to create 'current' link for package."
                    " Exit code %d. The command was: %s",
                  exit-code, join(command, " "));
  end;
end function;

// Download and install `release` into the standard location.
//
// Parameters:
//   force? - if true, the existing package is removed, if present, and
//     the package is re-installed. This applies transitively to dependencies.
//   deps? - if true, also install dependencies recursively.
//   dev-deps? - TODO
//   actives - #f or an <istring-table> mapping package names to <release>s.
//     These packages are omitted from the dependency version compatibility
//     checks because they're active in the current dev workspace.
// Values:
//   installed? - #t if an installation was performed or #f if the package was
//     already installed and `force?` was #f.
define sealed generic install
    (release :: <release>, #key force?, deps?, actives)
 => (installed? :: <bool>);

define method install
    (release :: <release>, #key force? :: <bool>, deps? :: <bool> = #t, actives)
 => (installed? :: <bool>)
  if (deps?)
    install-deps(release, force?: force?, actives: actives);
  end;
  if (force? & installed?(release))
    debug("Deleting package %s for forced install.", release);
    fs/delete-directory(release-directory(release), recursive?: #t);
  end;
  let dest-dir = source-directory(release);
  block ()
    if (installed?(release))
      debug("Package %s is already installed.", release);
      #f
    else
      download(release, dest-dir);
      #t
    end
  cleanup
    // Update current link even if download not needed, in case user is
    // updating to a previously installed version. (Might not want to update
    // the link for global installations, but it shouldn't hurt, and I might do
    // away with global installations altogether so ignoring it for now.)
    ensure-current-link(release, dest-dir);
  end block
end method;

// Install dependencies of `release`. If `force?` is true, remove and
// re-install all dependencies.
define method install-deps
    (release :: <release>, #key force? :: <bool>, actives :: false-or(<istring-table>))
  let cat = catalog();
  for (rel in resolve-release-deps(cat, release, dev?: #t, actives: actives))
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
                fs/directory-contents(package-directory)
              exception (fs/<file-system-error>)
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
