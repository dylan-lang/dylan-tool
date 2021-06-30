module: workspaces
synopsis: Manage developer workspaces

// TODO:
// * Display the number of registry files updated and the number unchanged.
//   It gives reassuring feedback that something went right when there's no
//   other output.

// The class of errors explicitly signalled by this module.
define class <workspace-error> (<simple-error>)
end class;

define function workspace-error
    (format-string :: <string>, #rest args)
  error(make(<workspace-error>,
             format-string: format-string,
             format-arguments: args));
end function;

define constant $workspace-file = "workspace.json";
define constant $default-library-key = "default-library";
define constant $active-key = "active";

define function str-parser (s :: <string>) => (s :: <string>) s end;

// Pulled out into a constant because it ruins code formatting.
define constant $workspace-file-format-string
  = #:str:[{
    %=: {
%s
    }
}
];

// Create a new workspace named `name` with active packages `pkg-names`.
define function new
    (name :: <string>, pkg-names :: <seq>,
     #key parent-directory :: <directory-locator> = fs/working-directory(),
          skip-workspace-check? :: <bool>)
  let check? = ~skip-workspace-check?;
  let file = check? & workspace-file(directory: parent-directory);
  if (file & check?)
    workspace-error("You appear to already be in a workspace directory: %s", file);
  end;
  let ws-dir = subdirectory-locator(parent-directory, name);
  let ws-file = as(<file-locator>, "workspace.json");
  let ws-path = merge-locators(ws-file, ws-dir);
  if (fs/file-exists?(ws-dir))
    workspace-error("Directory already exists: %s", ws-dir);
  end;
  fs/ensure-directories-exist(ws-path);
  fs/with-open-file (stream = ws-path,
                     direction: #"output",
                     if-does-not-exist: #"create")
    if (pkg-names.size = 0)
      pkg-names := #["<package-name-here>"];
    elseif (pkg-names.size = 1 & pkg-names[0] = "all")
      pkg-names := as(<vector>, pm/package-names(pm/load-catalog()));
    end;
    format(stream, $workspace-file-format-string,
           $active-key,
           join(pkg-names, ",\n", key: curry(format-to-string, "        %=: {}")));
  end;
  log-info("Wrote workspace file to %s.", ws-path);
end function;

// Update the workspace based on the workspace.json file or signal an error.
define function update () => ()
  let ws = find-workspace();
  log-info("Workspace directory is %s.", ws.workspace-directory);
  let cat = pm/load-catalog();
  update-active-packages(ws, cat);
  update-registry(ws, cat);
end function;

// <workspace> holds the parsed workspace configuration, and is the one object
// that knows the layout of the workspace directory:
//       workspace/
//         _build
//         active-package-1/
//         active-package-2/
//         registry/
define class <workspace> (<object>)
  constant slot workspace-directory :: <directory-locator>,
    required-init-keyword: directory:;
  constant slot workspace-registry :: <registry>,
    required-init-keyword: registry:;
  constant slot workspace-active-packages :: <seq> = #[], // <package>s
    init-keyword: active-packages:;
  constant slot workspace-default-library-name :: false-or(<string>) = #f,
    init-keyword: default-library-name:;
end class;

// Finds the workspace file somewhere in or above `directory` and creates a
// `<workspace>` from it. `directory` defaults to the current working
// directory.  Signals `<workspace-error>` if the file isn't found.
define function find-workspace
    (#key directory :: false-or(<directory-locator>)) => (w :: <workspace>)
  let path = workspace-file();
  if (~path)
    workspace-error("Workspace file not found."
                      " Current directory isn't under a workspace directory?");
  end;
  fs/with-open-file(stream = path, if-does-not-exist: #"signal")
    let object = json/parse(stream, strict?: #f, table-class: <istring-table>);
    if (~instance?(object, <table>))
      workspace-error("Invalid workspace file %s, must be a single JSON object", path);
    elseif (~element(object, $active-key, default: #f))
      workspace-error("Invalid workspace file %s, missing required key 'active'", path);
    elseif (~instance?(object[$active-key], <table>))
      workspace-error("Invalid workspace file %s, the '%s' element must be a map"
                        " from package name to {...}.",
                      $active-key, path);
    end;
    let registry = make(<registry>, root-directory: locator-directory(path));
    let active = object[$active-key];
    let library = element(object, $default-library-key, default: #f);
    if (~library & active.size = 1)
      for (_ keyed-by package-name in active)
        library := package-name;
      end;
    end;
    let active-packages
      = map(method (name)
              pm/find-package(pm/load-catalog(), name)
                | make(pm/<package>,
                       name: name,
                       releases: #[],
                       summary: format-to-string("active package %s", name),
                       description: "unknown",
                       contact: "unknown",
                       license-type: "unknown",
                       category: "unknown")
            end,
            key-sequence(object[$active-key])); // nothing in the values yet
    make(<workspace>,
         active-packages: active-packages,
         directory: locator-directory(path),
         registry: registry,
         default-library-name: library)
  end
end function;

// Search up from `directory` to find the workspace file. If `directory` is not
// supplied it defaults to the current working directory.
define function workspace-file
    (#key directory :: <directory-locator> = fs/working-directory())
 => (file :: false-or(<file-locator>))
  let ws-file = as(<file-locator>, $workspace-file);
  iterate loop (dir = directory)
    if (dir)
      let file = merge-locators(ws-file, dir);
      if (fs/file-exists?(file))
        file
      else
        loop(dir.locator-directory)
      end
    end
  end
end function;

define function active-package-names
    (ws :: <workspace>) => (names :: <seq>)
  map(pm/package-name, ws.workspace-active-packages)
end function;

// These next three should probably have methods on (<workspace>, <package>) too.
define function active-package-directory
    (ws :: <workspace>, pkg-name :: <string>) => (d :: <directory-locator>)
  subdirectory-locator(ws.workspace-directory, pkg-name)
end function;

define function active-package-file
    (ws :: <workspace>, pkg-name :: <string>) => (f :: <file-locator>)
  merge-locators(as(<file-locator>, "pkg.json"),
                 active-package-directory(ws, pkg-name))
end function;

define function active-package?
    (ws :: <workspace>, pkg-name :: <string>) => (_ :: <bool>)
  member?(pkg-name, ws.active-package-names, test: istring=?)
end function;

// Download the active packages and all of their resolved dependencies.  If an active
// package directory doesn't exist, the package is searched for in the catalog and
// downloaded. If not found, it is skipped with a warning. If the active package
// directory DOES exist, it is assumed to be current and the package is skipped.
//
// TODO(cgay): skipping the directory if it exists is pretty bad but is a start. Need to
// reload pkg.json, if it exists, and install new deps.
//
// We cobble together a fake "root" release to pass to pm/resolve-deps. The fake release
// has the active packages as its direct dependencies. The reason for doing it this way
// is to give pm/resolve-deps ALL the necessary info at the same time, including the
// active packages.
define function update-active-packages
    (ws :: <workspace>, cat :: pm/<catalog>)
  let (deps, actives) = find-active-package-deps(ws, cat);

  // Download active packages
  for (release in actives)
    let dir = active-package-directory(ws, release.pm/package-name);
    if (fs/file-exists?(dir))
      // TODO(cgay): need to load the pkg.json file in case it has been modified, for
      // example, by adding a new dependency. Then return it so that it can be included
      // when updating dependencies, which happens all at one time so that conflicting
      // deps can be detected.
      log-trace("Active package directory %s exists, not downloading %s.",
                dir, release.pm/package-name);
    else
      pm/download(release, dir);
    end;
  end;

  // Install dependencies. Note that resolve-deps doesn't return any of the packages
  // passed in `actives`, so all of the following packages will be installed to
  // ${DYLAN}/pkg.
  for (release in deps)
    pm/install(release, deps?: #f, force?: #f);
  end;
end function;

define function find-active-package-deps
    (ws :: <workspace>, cat :: pm/<catalog>)
  let actives = make(<istring-table>);
  let deps = make(<stretchy-vector>);
  for (pkg-name in ws.active-package-names)
    let rel = find-active-package-release(ws, pkg-name, cat);
    if (rel)
      actives[rel.pm/package-name] := rel;
      add!(deps, make(pm/<dep>,
                      package-name: rel.pm/package-name,
                      version: rel.pm/release-version));
    else
      log-warning("Skipping active package %=, not found in catalog.", pkg-name);
      log-warning("         If this is a new or private project then this is normal.");
      log-warning("         Create a pkg.json file for it and run update again to install");
      log-warning("         dependencies.");
    end;
  end;
  let releases = make(<stretchy-vector>);
  let root = make(pm/<release>,
                  version: make(pm/<branch-version>, branch: "__no_branch__"),
                  deps: as(pm/<dep-vector>, deps),
                  package: make(pm/<package>,
                                name: "ROOT__",
                                releases: releases,
                                summary: "workspace dummy package",
                                description: "workspace dummy package",
                                license-type: "unknown",
                                contact: "unknown",
                                category: "unknown",
                                location: $workspace-file));
  add!(releases, root); // back pointer
  let releases-to-install = pm/resolve-deps(root, cat, active: actives);
  values(releases-to-install, actives)
end function;

// Find or create a <release> for the given active package name by first reading the
// pkg.json file and then falling back to the latest release in the catalog, if any.
define function find-active-package-release
    (ws :: <workspace>, name :: <string>, cat :: pm/<catalog>)
 => (p :: false-or(pm/<release>))
  let path = active-package-file(ws, name);
  pm/read-package-file(path)
    | begin
        log-warning("No package found in %s, falling back to catalog.", path);
        pm/find-package-release(cat, name, pm/$latest)
      end
end function;

// Create/update a single registry directory having an entry for each library
// in each active package and all transitive dependencies.  This traverses
// package directories to find .lid files. Note that it assumes that .lid files
// that have no "Platforms:" section are generic, and writes a registry file
// for them (unless they're included in another LID file via the LID: keyword,
// in which case it is assumed they're for inclusion only).
define function update-registry
    (ws :: <workspace>, cat :: pm/<catalog>)
  let (deps, actives) = find-active-package-deps(ws, cat);
  for (rel in actives)
    update-for-directory(ws.workspace-registry,
                         active-package-directory(ws, rel.pm/package-name));
  end;
  for (rel in deps)
    update-for-directory(ws.workspace-registry, pm/source-directory(rel));
  end;
end function;
