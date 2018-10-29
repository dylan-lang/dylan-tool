Module: dylan-tool

// I'm undecided whether to go forward with this tool in the long run
// or to try and use Deft, but I don't want to deal with Deft's
// problems right now so this should be a pretty simple way to get
// workspaces and packages working.

// TODO:
// * Add a --verbose flag and hide much of the output when non-verbose.
// * Remove redundancy in 'update' command. It processes (shared?) dependencies
//   and writes registry files multiple times.
// * Display the number of registry files updated and the number unchanged.
//   It gives reassuring feedback that something went right when there's no
//   other output.

define constant $workspace-file = "workspace.json";

define function main () => (status :: <int>)
  block (return)
    let app = locator-name(as(<file-locator>, application-name()));
    let parser = make(cli/<parser>,
                      min-positional-options: 2,
                      max-positional-options: 2);
    let args = application-arguments();
    local method usage()
            format-err("Usage: %s install pkg version\n", app);
            format-err("       %s new workspace-name [pkg...]\n", app);
            format-err("       %s update\n", app);
            format-err("       %s list\n", app);
            return(2);
          end;
    args.size > 0 | usage();
    let cmd = args[0];
    select (cmd by str=)
      "install" =>
        // Install a specific package.
        args.size = 3 | usage();
        let pkg-name = args[1];
        let vstring = args[2];
        let pkg = pm/find-package(pm/load-catalog(), pkg-name, vstring);
        if (~pkg)
          error("Package %s not found.", pkg-name);
        end;
        pm/install(pkg);
      "list" =>
        list-catalog();
      "new" =>                  // Create a new workspace.
        args.size >= 2 | usage();
        apply(new, app, args[1], slice(args, 2, #f));
      "update" =>
        args.size = 1 | usage();
        update();        // Update the workspace based on config file.
      otherwise =>
        usage();
    end select;
    0
/* TODO: turn this into a 'let handler' that can be turned off by a --debug flag.
  exception (err :: <error>)
    format-err("Error: %s\n", err);
    1
*/
  end
end function main;

// List all package names, synopsis, and latest available numbered version.
//
// TODO: show installed version, if any.
define function list-catalog ()
  let cat = pm/load-catalog();
  for (pkg-name in sort(pm/package-names(cat)))
    let entry = pm/find-entry(cat, pkg-name);
    let latest = pm/find-package(cat, pkg-name, pm/$latest);
    format-out("%s (latest: %s) - %s\n",
               pkg-name, pm/version(latest), pm/synopsis(entry));
  end;
end;

define function str-parser (s :: <str>) => (s :: <str>) s end;

// Pulled out into a constant because it ruins code formatting.
define constant $workspace-file-format-string = #str:[{
    "active": {
%s
    }
}
];

define function new (app :: <str>, workspace-name :: <str>, #rest pkg-names)
  let workspace-file = find-workspace-file(fs/working-directory());
  if (workspace-file)
    error("You appear to already be in a workspace directory: %s", workspace-file);
  end;
  let workspace-dir = subdirectory-locator(fs/working-directory(), workspace-name);
  let workspace-file = as(<file-locator>, "workspace.json");
  let workspace-path = merge-locators(workspace-file, workspace-dir);
  if (fs/file-exists?(workspace-dir))
    error("Directory already exists: %s", workspace-dir);
  end;
  fs/ensure-directories-exist(workspace-path);
  fs/with-open-file (stream = workspace-path,
                     direction: #"output",
                     if-does-not-exist: #"create")
    if (pkg-names.size = 0)
      pkg-names := #["<package-name-here>"];
    end;
    format(stream, $workspace-file-format-string,
           join(pkg-names, "\n", key: curry(format-to-string, "        %=: {}")));
  end;
  format-out("Wrote workspace file to %s.\n", workspace-path);
  format-out("You may now run '%s update' in the new directory.\n", app);
end;

// Update the workspace based on the workspace config or signal an error.
define function update ()
  let config = load-workspace-config($workspace-file);
  format-out("Workspace directory is %s.\n", config.workspace-directory);
  update-active-packages(config);
  update-active-package-deps(config);
  update-registry(config);
end;

// <config> holds the parsed workspace configuration file, and is the one object
// that knows the layout of the workspace directory.  That is,
//       workspace/
//         registry/
//         active-package-1/
//         active-package-2/
define class <config> (<any>)
  constant slot active-packages :: <istr-map>, required-init-keyword: active:;
  constant slot workspace-directory :: <directory-locator>, required-init-keyword: workspace-directory:;
end;

define function load-workspace-config (filename :: <str>) => (c :: <config>)
  let path = find-workspace-file(fs/working-directory());
  if (~path)
    error("Workspace file not found. Current directory isn't under a workspace directory?");
  end;
  fs/with-open-file(stream = path, if-does-not-exist: #"signal")
    let object = json/parse(stream, strict?: #f, table-class: <istr-map>);
    if (~instance?(object, <map>))
      error("Invalid workspace file %s, must be a single JSON object", path);
    elseif (~element(object, "active", default: #f))
      error("Invalid workspace file %s, missing required key 'active'", path);
    elseif (~instance?(object["active"], <map>))
      error("Invalid workspace file %s, the 'active' element must be a map"
              " from package name to {...}.", path);
    end;
    make(<config>,
         active: object["active"],
         workspace-directory: locator-directory(path))
  end
end;

// Search up from `dir` to find $workspace-file.
define function find-workspace-file
   (dir :: <directory-locator>) => (file :: false-or(<file-locator>))
  if (~root-directory?(dir))
    let path = merge-locators(as(fs/<file-system-file-locator>, $workspace-file), dir);
    if (fs/file-exists?(path))
      path
    else
      locator-directory(dir) & find-workspace-file(locator-directory(dir))
    end
  end
end;

// TODO: Put something like this in system:file-system?  It seems
// straight-forward once you figure it out, but it took a few tries to
// figure out that root-directories returned locators, not strings,
// and it seems to depend on locators being ==, which I'm not even
// sure of. It seems to work.
define function root-directory? (loc :: <locator>)
  member?(loc, fs/root-directories())
end;

define function active-package-names (conf :: <config>) => (names :: <seq>)
  key-sequence(conf.active-packages)
end;

define function active-package-directory
    (conf :: <config>, pkg-name :: <str>) => (d :: <directory-locator>)
  subdirectory-locator(conf.workspace-directory, pkg-name)
end;

define function active-package-file
    (conf :: <config>, pkg-name :: <str>) => (f :: <file-locator>)
  merge-locators(as(<file-locator>, "pkg.json"),
                 active-package-directory(conf, pkg-name))
end;

define function active-package? (conf :: <config>, pkg-name :: <str>) => (_ :: <bool>)
  member?(pkg-name, conf.active-package-names, test: istr=)
end;

define function registry-directory (conf :: <config>) => (d :: <directory-locator>)
  subdirectory-locator(conf.workspace-directory, "registry")
end;

// Download active packages into the workspace directory if the
// package directories don't already exist.
define function update-active-packages (conf :: <config>)
  for (attrs keyed-by pkg-name in conf.active-packages)
    // Download the package if necessary.
    let pkg-dir = active-package-directory(conf, pkg-name);
    if (fs/file-exists?(pkg-dir))
      format-out("Active package %s exists, not downloading.\n", pkg-name);
    else
      let cat = pm/load-catalog();
      let pkg = pm/find-package(cat, pkg-name, pm/$head)
                  | pm/find-package(cat, pkg-name, pm/$latest);
      if (pkg)
        pm/download(pkg, pkg-dir);
      else
        format-out("WARNING: Skipping active package %s, not found in catalog.\n", pkg-name);
        format-out("WARNING: If this is a new or private project then this is normal.\n");
        format-out("WARNING: Create a pkg.json file for it and run update again to update deps.\n");
      end;
    end;
  end;
end;

// Update dep packages if needed.
define function update-active-package-deps (conf :: <config>)
  for (pkg-name in conf.active-package-names)
    // Update the package deps.
    let pkg = pm/read-package-file(active-package-file(conf, pkg-name));
    if (pkg)
      format-out("Installing deps for package %s.\n", pkg-name);
      // TODO: in a perfect world this wouldn't install any deps that
      // are also active packages. It doesn't cause a problem though,
      // as long as the registry points to the right place.
      pm/install-deps(pkg /* , skip: conf.active-package-names */);
    else
      format-out("WARNING: No pkg.json file found for active package %s."
                   " Not installing deps.\n", pkg-name);
    end;
  end;
end;

// Create/update a single registry directory having an entry for each
// library in each active package and all transitive dependencies.
define function update-registry (conf :: <config>)
  for (pkg-name in conf.active-package-names)
    let pkg = pm/read-package-file(active-package-file(conf, pkg-name));
    if (pkg)
      update-registry-for-package(conf, pkg, #f, #t);
      pm/do-resolved-deps(pkg, curry(update-registry-for-package, conf));
    else
      format-out("WARNING: No pkg.json file found for active package %s."
                   " Not creating registry file.\n", pkg-name);
    end;
  end;
end;

// Dig around in each package to find its libraries and create
// registry files for them.
define method update-registry-for-package (conf, pkg, dep, installed?)
  if (~installed?)
    error("Attempt to update registry for dependency %s, which"
            " is not yet installed. This may be a bug.", dep);
  end;
  let pkg-dir = if (active-package?(conf, pkg.pm/name))
                  active-package-directory(conf, pkg.pm/name)
                else
                  pm/source-directory(pkg)
                end;
  local method doit (dir, name, type)
          select (type)
            #"file" =>
              if (ends-with?(name, ".lid"))
                let lid-path = merge-locators(as(<file-locator>, name), dir);
                update-registry-for-lid(conf, lid-path);
              end;
            #"directory" =>
              // ., .., .git, etc.  Could be too broad a brush, but it's hard to imagine
              // putting Dylan code in .foo directories?
              if (~starts-with?(name, "."))
                fs/do-directory(doit, subdirectory-locator(dir, name));
              end;
          end;
        end;
  fs/do-directory(doit, pkg-dir);
end;

define function update-registry-for-lid
    (conf :: <config>, lid-path :: <file-locator>)
  let lib-name = library-from-lid(lid-path);
  let platform = lowercase(as(<str>, os/$platform-name));
  let directory = subdirectory-locator(conf.registry-directory, platform);
  let reg-file = merge-locators(as(<file-locator>, lib-name), directory);
  let relative-path = relative-locator(lid-path, conf.workspace-directory);
  let new-content = format-to-string("abstract://dylan/%s\n", relative-path);
  if (new-content ~= file-content(reg-file))
    fs/ensure-directories-exist(reg-file);
    format-out("Writing %s.\n", reg-file);
    fs/with-open-file(stream = reg-file, direction: #"output", if-exists?: #"overwrite")
      write(stream, new-content);
    end;
  end;
end;

// Read the full contents of a file and return it as a string.
// If the file doesn't exist return #f. (I thought if-does-not-exist: #f
// was supposed to accomplish this without the need for block/exception.)
define function file-content (path :: <locator>) => (s :: false-or(<str>))
  block ()
    fs/with-open-file(stream = path, if-does-not-exist: #"signal")
      read-to-end(stream)
    end
  exception (e :: fs/<file-does-not-exist-error>)
    #f
  end
end;

define function library-from-lid (path :: <file-locator>) => (library-name :: <str>)
  fs/with-open-file(stream = path)
    let whitespace = #regex:"[ \t]";
    let line = #f;
    block (return)
      while (line := read-line(stream, on-end-of-stream: #f))
        let parts = split(line, whitespace, remove-if-empty?: #t);
        if (parts.size > 1 & istr=(parts[0], "library:"))
          return(parts[1])
        end;
      end;
      error("No library found in %s", path);
    end;
  end;
end;

exit-application(main());
