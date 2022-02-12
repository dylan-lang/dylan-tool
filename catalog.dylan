Module: %pacman

// Catalog format version string, names a subdirectory in the catalog
// repository. When changing the format of the catalog we'll write a converter
// from the old format to the new format and use a new subdirectory for it, to
// allow for easily reverting to the old format.
define constant $catalog-format = "v1";

// Point this at your checkout of pacman-catalog when testing additions to the
// catalog and the catalog will be loaded from the subdirectory named the same
// as $catalog-format.
define constant $catalog-env-var = "DYLAN_CATALOG";

define constant $catalog-local-directory-name = "pacman-catalog";

define class <catalog-error> (<package-error>)
end class;

define class <package-missing-error> (<catalog-error>)
  constant slot package-name :: <string>,
    required-init-keyword: package-name:;
end class;

define function catalog-error
    (fmt :: <string>, #rest args)
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end function;

// Packages with no category are categorized thusly.
define constant $uncategorized = "Uncategorized";

define constant $pacman-catalog-release :: <release>
  = begin
      let releases = make(<stretchy-vector>);
      let package = make(<package>,
                         name: "pacman-catalog",
                         releases: releases,
                         description: "The pacman catalog",
                         contact: "carlgay@gmail.com",
                         category: $uncategorized,
                         keywords: #[]);
      let release = make(<release>,
                         package: package,
                         version: make(<branch-version>, branch: "master"),
                         deps: as(<dep-vector>, #[]),
                         license: "MIT",
                         url: "https://github.com/dylan-lang/pacman-catalog",
                         license-url: "https://github.com/dylan-lang/pacman-catalog/LICENSE");
      add!(releases, release);
      release
    end;

// The catalog knows what packages (and releases thereof) exist.
define sealed class <catalog> (<object>)
  // The root of the catalog directory. This is not the pacman-catalog
  // repository root directory, it's the directory containing the one- or
  // two-letter subdirectories. Currently it's the pacman-catalog/v1 directory
  // and will change when the catalog format changes.
  constant slot catalog-directory :: <directory-locator>,
    required-init-keyword: directory:;
  // Lowercase package name string -> <package>
  constant slot catalog-package-cache :: <istring-table> = make(<istring-table>);
end class;

// Loading the catalog once per session should be enough, so cache it here.
// This is a thread-local variable so that we can bind it to a dummy catalog
// while installing the catalog package itself, to prevent infinite recursion.
// Access this via catalog() rather than directly.
define thread variable *catalog* :: false-or(<catalog>) = #f;

define variable *override-logged?* = #f;

// Get the package catalog. Packages are loaded lazily and stored in the
// catalog's cache. If the DYLAN_CATALOG environment variable is set then that
// directory is used and no attempt is made to download the latest catalog.
define function catalog
    () => (c :: <catalog>)
  if (*catalog*)
    *catalog*
  else
    let override = os/getenv($catalog-env-var);
    let directory
      = if (override)
          if (~*override-logged?*)
            log-warning("Using override catalog from $%s: %s", $catalog-env-var, override);
            *override-logged?* := #t;
          end;
          subdirectory-locator(as(<directory-locator>, override), $catalog-format)
        else
          subdirectory-locator(package-manager-directory(),
                               $catalog-local-directory-name,
                               $pacman-catalog-release.release-version.version-to-string,
                               $source-directory-name,
                               $catalog-format)
        end;
    // We pass deps?: #f here to prevent infinite recursion when `catalog` is
    // called again. pacman-catalog is a data-only package and will never have
    // any deps.
    if (~override)
      install($pacman-catalog-release,
              force?: too-old?(directory),
              deps?: #f);
    end;
    *catalog* := make(<catalog>, directory: directory)
  end
end function;

define function find-package
    (cat :: <catalog>, name :: <string>) => (pkg :: <package>)
  let name = lowercase(name);
  let cache = catalog-package-cache(cat);
  cached-package(cat, name)
    | cache-package(cat, load-package(cat, name))
end function;

define function load-all-packages
    (cat :: <catalog>) => (packages :: <seq>)
  let packages = make(<stretchy-vector>);
  local
    method load-one (dir, name, type)
      select (type)
        #"directory" =>
          do-directory(load-one, subdirectory-locator(dir, name));
        #"file" =>
          // TODO: in release after 2020.1 use file-locator here.
          let file = merge-locators(as(<file-locator>, name), dir);
          log-debug("loading %s", file);
          add!(packages, load-package-file(cat, name, file));
      end;
    end method;
  do-directory(load-one, cat.catalog-directory);
  packages
end function;

// Fetch the catalog again if it's older than this.
define constant $catalog-freshness :: <duration> = make(<duration>, minutes: 10);

define function too-old?
    (path :: <locator>) => (old? :: <bool>)
  block ()
    let mod-time = file-property(path, #"modification-date");
    let now = current-date();
    now - mod-time > $catalog-freshness
  exception (<file-system-error>)
    // TODO: catch <file-does-not-exist-error> instead
    // https://github.com/dylan-lang/opendylan/issues/1147
    #t
  end
end function;

define function cached-package
    (cat :: <catalog>, name :: <string>) => (pkg :: false-or(<package>))
  element(cat.catalog-package-cache, name, default: #f)
end function;

define function cache-package
    (cat :: <catalog>, pkg :: <package>) => (pkg :: <package>)
  let cache = cat.catalog-package-cache;
  let name = pkg.package-name;
  let cached = element(cache, name, default: #f);
  if (~cached)
    cache[name] := pkg
  elseif (cached ~== pkg)
    catalog-error("attempt to cache different instance of package %s", pkg);
  end;
  pkg
end function;

// Exported
define generic find-package-release
    (catalog :: <catalog>, name :: <string>, version :: <object>)
 => (release :: false-or(<release>));

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <string>)
 => (p :: false-or(<release>))
  find-package-release(cat, name, string-to-version(ver))
end method;

// Find the latest released version of a package.
define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <latest>)
 => (p :: false-or(<release>))
  let package = find-package(cat, name);
  let releases = package & package.package-releases;
  if ((releases | #[]).size > 0)        // does 0 releases even make sense?
    releases[0]
  end
end method;

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <version>)
 => (p :: false-or(<release>))
  let package = find-package(cat, name);
  package & find-release(package, ver, exact?: #t)
end method;

// Signal an indirect instance of <package-error> if there are any problems
// found in the catalog. If `cached?` is true, don't try to load packages. This
// is intended for tests that construct a catalog in memory instead of with
// files.
define function validate-catalog
    (cat :: <catalog>, #key cached? :: <bool>) => ()
  // A reusable memoization cache (release => result).
  let cache = make(<table>);
  let packages = if (cached?)
                   value-sequence(cat.catalog-package-cache)
                 else
                   load-all-packages(cat)
                 end;
  if (empty?(packages))
    catalog-error("no packages found in catalog. Wrong directory?");
  end;
  for (package in packages)
    for (release in package.package-releases)
      resolve-deps(release, cat, cache: cache);
    end;
  end;
end function;

// Write a package to the catalog in JSON format.
define function write-package-file
    (cat :: <catalog>, package :: <package>) => ()
  let file = package-locator(cat, package);
  ensure-directories-exist(file);
  with-open-file (stream = file, direction: #"output", if-exists: #"replace")
    json/print(package, stream, indent: 2);
  end;
end function;

define generic package-locator
    (cat :: <catalog>, package) => (file :: <file-locator>);

define method package-locator
    (cat :: <catalog>, package :: <package>) => (file :: <file-locator>)
  package-locator(cat, package.package-name)
end method;

define method package-locator
    (cat :: <catalog>, name :: <string>) => (file :: <file-locator>)
  let root = cat.catalog-directory;
  let dir = select (name.size)
              1 => subdirectory-locator(root, "1");
              2 => subdirectory-locator(root, "2");
              otherwise =>
                subdirectory-locator(subdirectory-locator(root, copy-sequence(name, end: 2)),
                                     copy-sequence(name, start: 2, end: min(4, name.size)))
            end;
  merge-locators(as(<file-locator>, name), dir)
end method;

// The JSON printer calls json/do-print. We convert most objects to tables,
// which the JSON printer knows how to print.

define method json/do-print
    (package :: <package>, stream :: <stream>)
  json/print(to-table(package), stream);
end method;

define method json/do-print
    (release :: <release>, stream :: <stream>)
  json/print(to-table(release), stream);
end method;

define method json/do-print
    (dep :: <dep>, stream :: <stream>)
  let t = make(<istring-table>);
  t["name"]    := dep.package-name;
  t["version"] := dep.dep-version;
  json/print(t, stream);
end method;

define method json/do-print
    (version :: <version>, stream :: <stream>)
  json/print(version-to-string(version), stream);
end method;

define function load-package
    (cat :: <catalog>, name :: <string>) => (package :: <package>)
  let file = package-locator(cat, name);
  load-package-file(cat, name, file);
end function;

define function load-package-file
    (cat :: <catalog>, name :: <string>, file :: <file-locator>) => (package :: <package>)
  log-debug("loading %s", file);
  let json
    = block ()                  // if-does-not-exist: #f doesn't work
        with-open-file (stream = file, direction: #"input")
          json/parse(stream)
        end
      exception (<file-does-not-exist-error>)
        signal(make(<package-missing-error>,
                    package-name: name,
                    format-string: "package %= not in catalog",
                    format-arguments: list(name)))
      end;
  let stored-name = json["name"];
  if (stored-name ~= name)
    log-warning("%s: loaded package name is %=, expected %=",
                file, stored-name, name);
  end;
  let releases = make(<stretchy-vector>);
  let package = make(<package>,
                     name: name,
                     description: json["description"],
                     contact: json["contact"],
                     keywords: json["keywords"],
                     releases: releases);
  local
    method to-release (t :: <table>) => (r :: <release>)
      make(<release>,
           package: package,
           version: string-to-version(t["version"]),
           deps: map-as(<dep-vector>, string-to-dep, t["deps"]),
           url: element(t, "url", default: #f)
             | element(t, "location", default: ""),
           license: t["license"],
           license-url: element(t, "license-url", default: ""))
    end;
  map-into(releases, to-release, json["releases"]);
  sort!(releases, test: \>);
  cat.catalog-package-cache[name] := package
end function;

/* TODO: validate each release...

    if (version = $latest)
      catalog-error("version 'latest' is not a valid package version in the catalog;"
                      " specify a semantic version instead.");
    end;
    let version-string = version-to-string(version);
    if (element(seen, version-string, default: #f))
      catalog-error("duplicate release version: %s@%s", name, vstring);
    end;

*/
