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

// Create a new workspace named `name` under `parent-directory`. If `parent-directory` is
// not supplied use the standard location.
//
// TODO: validate `name`
define function new
    (name :: <string>, #key parent-directory :: false-or(<directory-locator>))
 => (w :: false-or(<workspace>))
  let dir = parent-directory | fs/working-directory();
  let ws-dir = subdirectory-locator(dir, name);
  let ws-file = as(<file-locator>, $workspace-file);
  let ws-path = merge-locators(ws-file, ws-dir);
  let existing = find-workspace-file(dir);
  if (existing)
    workspace-error("Can't create workspace file %s because it is inside another"
                      " workspace, %s.", ws-path, existing);
  end;
  if (fs/file-exists?(ws-path))
    log-info("Workspace already exists: %s", ws-path);
  else
    fs/ensure-directories-exist(ws-path);
    fs/with-open-file (stream = ws-path,
                       direction: #"output", if-does-not-exist: #"create",
                       if-exists: #"error")
      format(stream, "# Dylan workspace %=\n\n{}\n", name);
    end;
    log-info("Workspace created: %s", ws-path);
  end;
  load-workspace(ws-dir)
end function;

// Update the workspace based on the workspace.json file or signal an error.
define function update () => ()
  let ws = load-workspace(fs/working-directory());
  log-info("Workspace directory is %s.", ws.workspace-directory);
  let cat = pm/catalog();
  update-deps(ws, cat);
  update-registry(ws, cat);
end function;

// <workspace> holds the parsed workspace configuration, and is the one object
// that knows the layout of the workspace directory:
//       workspace/
//         _build
//         active-package-1/pkg.json
//         active-package-2/pkg.json
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
define function load-workspace
    (directory :: <directory-locator>) => (w :: <workspace>)
  let path = find-workspace-file(directory)
    | workspace-error("Workspace file not found for %s", directory);
  fs/with-open-file(stream = path, if-does-not-exist: #"signal")
    let object = json/parse(stream, strict?: #f, table-class: <istring-table>);
    if (~instance?(object, <table>))
      workspace-error("Invalid workspace file %s, must be a single JSON object", path);
    end;
    let ws-dir = locator-directory(path);
    let registry = make(<registry>, root-directory: ws-dir);
    let active-packages = find-active-packages(ws-dir);
    let default-library = element(object, $default-library-key, default: #f);
    if (~default-library & active-packages.size = 1)
      // TODO: this isn't right. Should find the actual libraries, from the LID
      // files, and if there's only one "*-test*" library, choose that.
      for (pkg in active-packages)
        default-library := pm/package-name(pkg);
      end;
    end;
    make(<workspace>,
         active-packages: active-packages,
         directory: locator-directory(path),
         registry: registry,
         default-library-name: default-library)
  end
end function;

// Search up from `directory` to find the workspace file.
define function find-workspace-file
    (directory :: <directory-locator>) => (file :: false-or(<file-locator>))
  let ws-file = as(<file-locator>, $workspace-file);
  iterate loop (dir = simplify-locator(directory))
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

// Find `directory`/*/pkg.json and turn them into a sequence of package <release>s.
define function find-active-packages
    (directory :: <directory-locator>) => (pkgs :: <seq>)
  let packages = make(<stretchy-vector>);
  for (locator in fs/directory-contents(directory))
    if (instance?(locator, <directory-locator>))
      let loc = merge-locators(as(<file-locator>, "pkg.json"), locator);
      if (fs/file-exists?(loc))
        let pkg = pm/read-package-file(loc);
        add!(packages, pkg);
      end;
    end;
  end;
  packages
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

// Resolve active package dependencies and install them.
define function update-deps
    (ws :: <workspace>, cat :: pm/<catalog>)
  let (deps, actives) = find-active-package-deps(ws, cat);
  // Install dependencies. Note that resolve-deps doesn't return any of the packages
  // passed in `actives`, so all of the following packages will be installed to
  // ${DYLAN}/pkg.
  for (release in deps)
    pm/install(release, deps?: #f, force?: #f);
  end;
end function;

// Find the transitive dependencies of the active packages in workspace `ws` by
// creating a fake release with the combined dependencies and calling
// resolve-deps on it.
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
      log-warning("  If this is a new or private project then this is normal.");
    end;
  end;
  let releases = make(<stretchy-vector>);
  let root = make(pm/<release>,
                  url: concat("file://", as(<string>, ws.workspace-directory)),
                  version: pm/$latest,
                  deps: as(pm/<dep-vector>, deps),
                  license: "none",
                  package: make(pm/<package>,
                                name: "WORKSPACE__",
                                releases: releases,
                                description: "workspace active packages"));
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
  let registry = ws.workspace-registry;
  for (rel in actives)
    update-for-directory(registry, active-package-directory(ws, rel.pm/package-name));
  end;
  for (rel in deps)
    update-for-directory(registry, pm/source-directory(rel));
  end;
end function;
