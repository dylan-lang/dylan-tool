Module: %pacman
Synopsis: Support for semantic versions and branch versions

// I'm not sure if branch versions need to exist. Leaving the code here for
// now, but I'm certain branch versions don't ever belong in the catalog. My
// current thinking is that branches are only ever used for active packages,
// and those are checked out into the workspace manually.

// A version is a specification that points to a specific version control commit so that
// an exact version of code may be retrieved. It might be a tag, a branch, or even a
// specific commit hash.
define abstract class <version> (<object>)
end;

// version-branch returns the name of the branch to checkout. For example "master" for
// branch versions or "v1.2.3" for semantic versions. For Git this can be thought of as
// the value of the `git clone --branch` flag.
define generic version-branch (v :: <version>) => (branch :: <string>);

// version-to-string returns the string representation of the version. For semantic
// versions this is the bare "1.2.3" the patch number is always included, even if zero.
define generic version-to-string (v :: <version>) => (s :: <string>);

define method print-object
    (v :: <version>, stream :: <stream>) => ()
  if (*print-escape?*)
    printing-object (v, stream)
      write(stream, version-to-string(v));
    end;
  else
    write(stream, version-to-string(v));
  end;
end method;


// A semantic version as per the http://semver.org 2.0 specification. Note that only
// numbered versions (semantic versions) appear in the catalog, and they are ordered
// most-recent-first in the catalog, so they need methods on < and =, while other
// versions don't.
//
// TODO(cgay): support <pre-release> and <build> specifiers, per the spec.
define class <semantic-version> (<version>)
  constant slot version-major :: <int>, required-init-keyword: major:;
  constant slot version-minor :: <int>, required-init-keyword: minor:;
  constant slot version-patch :: <int>, required-init-keyword: patch:;
end class;

define method version-to-string
    (v :: <semantic-version>) => (s :: <string>)
  format-to-string("%d.%d.%d", v.version-major, v.version-minor, v.version-patch)
end;

// Releases must be tagged with the SemVer prefixed by "v".
define method version-branch
    (v :: <semantic-version>) => (branch :: <string>)
  concat("v", v.version-to-string)
end;

// A branch version, such as "master" or "cdb4af3". (Not yet sure if I'll need a separate
// class for <commit-version>. Let's pretend we don't.) Branch versions can't be
// published in the catalog and are only intended to be used during development.
define class <branch-version> (<version>)
  constant slot version-branch :: <string>, required-init-keyword: branch:;
end class;

define method version-to-string
    (v :: <branch-version>) => (s :: <string>)
  v.version-branch
end;

define method \=
    (v1 :: <semantic-version>, v2 :: <semantic-version>) => (_ :: <bool>)
  v1.version-major == v2.version-major
    & v1.version-minor == v2.version-minor
    & v1.version-patch == v2.version-patch
end method;

define method \=
    (v1 :: <branch-version>, v2 :: <branch-version>) => (_ :: <bool>)
  v1.version-branch = v2.version-branch
end method;

define method \<
    (v1 :: <semantic-version>, v2 :: <semantic-version>) => (_ :: <bool>)
  v1.version-major < v2.version-major
    | (v1.version-major == v2.version-major
         & (v1.version-minor < v2.version-minor
              | (v1.version-minor == v2.version-minor
                   & v1.version-patch < v2.version-patch)))
end method;

// Branch versions are for active development (at least in my current conception of how
// things should work; this may change) so they are always newer (i.e., \>) than semantic
// versions.
define method \<
    (v1 :: <branch-version>, v2 :: <semantic-version>) => (_ :: <bool>)
  #f
end method;

define method \<
    (v1 :: <semantic-version>, v2 :: <branch-version>) => (_ :: <bool>)
  #t
end method;

define method \<
    (v1 :: <branch-version>, v2 :: <branch-version>) => (_ :: <bool>)
  v1.version-branch < v2.version-branch // arbitrary tie-breaker
end method;



// <latest> is a special version representing whatever the latest <semantic-version> for
// a package. There is no way to compare <latest> to <branch-version>, and there is no
// need to compare it to <semantic-version> since semantic versions in the catalog are
// always sorted newest to oldest. <latest> is only allowed as a dependency in
// dylan-package.json files, not in the catalog.
define class <latest> (<version>, <singleton-object>) end;

define constant $latest :: <latest> = make(<latest>);

define method version-to-string
    (v :: <latest>) => (s :: <string>)
  $latest-name
end;


define constant $semantic-version-regex
  = #:regex:{^(\d+)\.(\d+)(?:\.(\d+))?(-[0-9A-Za-z.-]+)?$};

// Parse a version from a string such as "1.0" or "1.0.2". Major and minor version are
// required. If patch is omitted it defaults to 0. Branch versions such as "master" are
// also allowed, and the special string "latest" refers to the latest numbered version.
define function string-to-version
    (original-input :: <string>) => (_ :: <version>)
  let input = strip(original-input);
  let (match?, maj, min, pat, pre-release)
    = re/search-strings($semantic-version-regex, input);
  if (match?)
    if (pre-release)
      package-error("pre-release version specs are not yet supported: %=",
                    original-input);
    end;
    maj := string-to-integer(maj);
    min := string-to-integer(min);
    pat := if (pat) string-to-integer(pat) else 0 end;
    if (maj < 0 | min < 0 | pat < 0 | (maj + min + pat = 0))
      package-error("invalid version spec %=", original-input);
    end;
    make(<semantic-version>, major: maj, minor: min, patch: pat)
  elseif (istring=(input, "latest"))
    $latest
  elseif (empty?(input) | decimal-digit?(input[0]))
    package-error("invalid version string: %=", original-input);
  else
    // Should really do more sanity checking on the branch name...
    make(<branch-version>, branch: input)
  end
end function;
