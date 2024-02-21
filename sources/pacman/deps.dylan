Module: %pacman
Synopsis: Dependency specification and resolution


define class <dep-error> (<package-error>) end;

// TODO(cgay): all the errors explicitly convert there args to strings because, for
// reasons I never fully understood, the error printing code doesn't call the
// print-object methods to print the args.

define function dep-error
    (format-string, #rest args)
  signal(if (instance?(format-string, <condition>))
           format-string
         else
           make(<dep-error>,
                format-string: format-string,
                format-arguments: args)
         end);
end function;

define class <dep-conflict> (<dep-error>) end;

// A dependency on a specific version of a package.
define class <dep> (<object>)
  constant slot package-name :: <string>, required-init-keyword: package-name:;
  constant slot dep-version :: <version>, required-init-keyword: version:;
end class;

define method initialize
    (dep :: <dep>, #key) => ()
  next-method();
  validate-package-name(dep.package-name);
end method;

define method print-object
    (dep :: <dep>, stream :: <stream>) => ()
  if (*print-escape?*)
    printing-object (dep, stream)
      write(stream, dep-to-string(dep));
    end;
  else
    write(stream, dep-to-string(dep))
  end;
end method;

define function dep-to-string
    (dep :: <dep>) => (_ :: <string>)
  if (dep.dep-version = $latest)
    dep.package-name
  else
    concat(dep.package-name, "@", version-to-string(dep.dep-version))
  end
end function;

// We want to avoid checking a lot of duplicate dependencies and this enables
// preventing those duplicates with add-new!(..., dep, test: \=)
define method \=
    (d1 :: <dep>, d2 :: <dep>) => (_ :: <bool>)
  string-equal-ic?(d1.package-name, d2.package-name) & d1.dep-version = d2.dep-version
end method;

// Parse a dependency spec. Examples:
//   foo            -- same as "foo@latest", i.e., latest numbered release
//   foo@1.0        -- same as "foo@1.0.0"
//   foo@1.2.3
//   foo@feature    -- HEAD of the 'feature' branch
//
// TODO(cgay): I don't think "foo" or "foo@latest" should be supported at this level.  It
// should probably be handled at the dylan-tool or workspaces level, and be explicitly
// resolved to the latest <semantic-version> immediately.
define function string-to-dep
    (input :: <string>) => (d :: <dep>)
  let (name, version) = apply(values, map(strip, split(strip(input), "@", count: 2)));
  make(<dep>,
       package-name: name,
       version: if (version) string-to-version(version) else $latest end)
end function;

// A convenience interface to resolve-deps.
define function resolve-release-deps
    (cat :: <catalog>, release :: <release>,
     #key dev? :: <bool>, actives :: false-or(<istring-table>), cache)
 => (deps :: <seq>)
  let dev-deps = if (dev?)
                   release.release-dev-dependencies
                 else
                   as(<dep-vector>, #())
                 end;
  // Add the release as a dependency of itself so that it will be included in circular
  // dependency checking. Note that this is mostly for releases in the catalog; workspace
  // packages are normally included in `actives` and won't be checked.
  let reldep = make(<dep>,
                    package-name: release.package-name,
                    version: release.release-version);
  let deps = as(<dep-vector>, add!(release.release-dependencies, reldep));
  resolve-deps(cat, deps, dev-deps, actives, cache: cache)
end function;

// Resolve a set of dependencies to a set of specific releases, using `cat` as the world
// of potential releases. `actives` maps package names to releases that are active in the
// current workspace and therefore should be treated specially. If any package
// encountered during resolution has a dependency on one of the active packages, that
// dependency is ignored since the active package will be used during the build process
// anyway. The set of returned releases does not include the active releases.
//
// Signal <dep-error> if dependencies can't be resolved due to circularities,
// conflicting constraints, or if they are simply missing from the catalog.
//
// The algorithm used here is based on my understanding of
// https://research.swtch.com/vgo-principles, which can be very roughly summarized as
// "providing repeatable builds by preferring the lowest possible specified version of
// any package".
//
// We are given the deps of a release that needs to be built. That release is the root of
// a graph. Its deps form the second layer of a graph. The releases that match those deps
// form the third level of the graph, and the deps of those releases form the fourth,
// etc. So we have a graph in which the layers alternate between potential releases and
// their deps. This tree gets big fast. The result for any given release is memoized.
//
// Each dep specifies only its minimum required version, e.g., P@1.2.3.  These are
// semantic versions so if two dependencies on P specify different major versions it is
// an error.
//
// Releases with no deps terminate the recursion and as results percolate up the stack
// they are combined with other results to keep only the maximum minimum version for each
// package.
//
// Note: The assumption is that deps are per package, not per library. That is, it's not
// possible for two independent libraries in one package to depend on different versions
// of a package. For that case, make two packages.
define function resolve-deps
    (cat :: <catalog>, deps :: <dep-vector>, dev-deps :: <dep-vector>,
     actives :: false-or(<istring-table>), #key cache)
 => (releases :: <seq>)
  let cache = cache | make(<table>);
  local
    // Use `dylan --debug --verbose update` to see this trace output.
    method %trace (depth, return-value, fmt, #rest format-args)
      let indent = make(<string>, size: depth * 2, fill: ' ');
      apply(trace, concat(indent, fmt), format-args);
      return-value
    end,
    // Resolve the deps for a single release into a set of specific releases
    // required in order to build it. The recursion terminates when a release
    // has no deps or if a cached result exists.
    method resolve-release (rel, seen, depth) => (releases :: <list>)
      %trace(depth, #f, "resolve-release(rel: %=, seen: %=)", rel, seen);
      let memo = element(cache, rel, default: #f); // use memoized result
      if (memo)
        %trace(depth, memo, "<= memoized result %s", memo)
      else
        let pname = rel.package-name;
        if (member?(pname, seen, test: \=))
          dep-error("circular dependency: %=", pair(pname, seen))
        end;
        // TODO: shouldn't need as(<list>) here
        let resolved = %resolve-deps(as(<list>, rel.release-dependencies),
                                     pair(pname, seen),
                                     depth + 1);
        cache[rel] := resolved;
        %trace(depth, resolved, "caching %s => %s", rel, resolved);
      end
    end method,
    // Iterate over a single release's deps resolving them to lists of specific minimum
    // releases, then combine those releases into one list by taking the maximum minimum
    // release version needed for each package.  When looking up deps, always prefer the
    // active packages, so that it isn't necessary for active packages to exist in the
    // catalog.
    method %resolve-deps (deps, seen, depth) => (releases :: <list>)
      %trace(depth, #f, "%%resolve-deps(deps: %s, seen: %=)", as(<list>, deps), seen);
      let maxima = make(<istring-table>);
      for (dep in deps)
        let pname = dep.package-name;
        let rel = (actives & element(actives, pname, default: #f))
                  | begin
                      let pkg = find-package(cat, pname)
                        | dep-error("package not found for %=", dep-to-string(dep));
                      find-release(pkg, dep.dep-version, exact?: #f)
                        | dep-error("no release found matching dependency %=",
                                    dep-to-string(dep))
                    end;
        for (release in pair(rel, resolve-release(rel, seen, depth + 1)))
          let pkg-name = release.package-name;
          if (~(actives & element(actives, pkg-name, default: #f)))
            let current-max = element(maxima, pkg-name, default: #f);
            maxima[pkg-name] := max-release(current-max, release, seen: pair(pkg-name, seen));
          end;
        end;
      end;
      let releases = as(<list>, value-sequence(maxima));
      %trace(depth, releases, "<= %s", releases);
    end method;
  block ()
    let releases = %resolve-deps(deps, #(), 0);
    if (~empty?(dev-deps))
      // TODO: this doesn't need to be a separate call to %resolve-deps unless we want to
      // give a more contextualized error message, which isn't currently done.
      let dev-releases = %resolve-deps(dev-deps, #(), 0);
      // Some refactoring may be needed, to make %resolve-deps return a list of deps
      // instead of releases, but this'll do for now.
      let all-deps = as(<dep-vector>,
                        map(method (r)
                              make(<dep>,
                                   package-name: r.package-name,
                                   version: r.release-version)
                            end,
                            concat(releases, dev-releases)));
      // Re-resolve the combined list to ensure maximin'd versions of shared packages
      // and no major version conflicts.
      let combined = %resolve-deps(all-deps, #(), 0);
      releases := reconcile-prod-dev-deps(combined, releases)
    end;
    releases
  exception (ex :: <package-missing-error>)
    dep-error(make(<dep-error>,
                   format-string: "package %= not in catalog",
                   format-arguments: list(ex.package-name)));
  end
end function;


// Adjust result to prefer non-dev dependencies and ensure that what is tested is what is
// run in production. Ex: for prod-dep->a@1.0->b@1.0 and dev-dep->c@1.0->b@1.1 the b@1.0
// release should be preferred even though it's a lower minor version, because it's what
// will be used in production.
define function reconcile-prod-dev-deps
    (combined-releases, main-releases) => (releases)
  let releases = #();
  for (combined in combined-releases)
    let main = find-element(main-releases,
                            method (r)
                              r.package-name = combined.package-name
                            end);
    if (~main | combined == main)
      releases := pair(combined, releases);
    else
      // TODO: should have a flag to use the dev dependency if user believes it's safe.
      warn("Using %s instead of higher dev dependency %s to ensure"
             " consistent dev and non-dev builds.",
           main, combined);
      releases := pair(main, releases);
    end
  end;
  releases
end function;

// Find the newest of two releases. They could have semantic versions or branch versions,
// which aren't really comparable. We prefer the branch version arbitrarily. Differing
// branch versions or differing major version number for semantic versions causes a
// `<dep-conflict>` error. `seen` is for better error messages only, and should be a
// sequence of package names seen so far during dependency resolution.
define method max-release
    (current == #f, release :: <release>, #key seen = #[]) => (r :: <release>)
  release
end method;

define method max-release
    (current :: <release>, release :: <release>, #key seen = #[]) => (r :: <release>)
  let relver = release.release-version;
  let curver = current.release-version;
  if (instance?(relver, <branch-version>))
    if (instance?(curver, <branch-version>))
      if (relver ~= curver)
        dep-error(make(<dep-conflict>,
                       format-string: "dependencies on two different branches of"
                         " the same package: %= and %= (path: %s)",
                       format-arguments: list(release-to-string(current),
                                              release-to-string(release),
                                              join(reverse(seen), " => "))));
      end;
      current
    else
      release                // prefer branch version
    end
  else
    if (instance?(curver, <branch-version>))
      current                 // prefer branch version
    else
      // Both releases are SemVer.
      let release-major = release.release-version.version-major;
      let current-major = current.release-version.version-major;
      if (release-major ~= current-major)
        dep-error(make(<dep-conflict>,
                       format-string: "dependencies on conflicting major versions"
                         " of the same package: %= and %= (path: %s)",
                       format-arguments: list(release-to-string(current),
                                              release-to-string(release),
                                              join(reverse(seen), " => "))));
      end;
      max(current, release)
    end
  end
end method;
