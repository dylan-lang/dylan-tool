Module: dylan-tool

// I'm undecided whether to go forward with this tool in the long run
// or to try and use Deft, but I don't want to deal with Deft's
// problems right now so this should be a pretty simple way to get
// workspaces and packages working.

define constant $workspace-file = "workspace.json";

define function main () => (status :: <int>)
  block (return)
    let parser = make(cli/<parser>,
                      min-positional-options: 2,
                      max-positional-options: 2);
    let args = application-arguments();
    if (args.size = 0)
      format-err("Usage: %s <subcommand> ...", application-name());
      return(2);
    end;
    let cmd = args[0];
    select (cmd by str=)
      "install" =>
        // Install a specific package.
        if (args.size ~= 2)
          format-err("Usage: %s install <pkg>\n", application-name());
          return(2);
        end;
        let pkg-name = args[1];
        let pkg = pkg/find-package(pkg/load-catalog(), pkg-name, pkg/$latest);
        if (~pkg)
          error("Package %s not found.", pkg-name);
        end;
        pkg/install(pkg);
      "update" =>
        // Update the workspace based on config file.
        update();
    end select;
    0
  exception (err :: <error>)
    format-err("Error: %s\n", err);
    1
  end
end function main;

// Update the workspace based on the workspace config or signal an error.
define function update ()
  let config = load-workspace-config($workspace-file);
  update-active-packages(config);
  update-deps(config);
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
  // TODO: search up directory tree to find nearest workspace file.
  let workspace-dir = working-directory();
  let path = merge-locators(as(<file-system-file-locator>, $workspace-file),
                            workspace-dir);
  with-open-file(stream = path, if-does-not-exist: #"error")
    let object = json/parse(stream, strict?: #f, table-class: <istr-map>);
    if (~instance?(object, <map>))
      error("invalid workspace file %s, must be a single JSON object", path);
    elseif (~element(object, "active", default: #f))
      error("invalid workspace file %s, missing required key 'active'", path);
    end;
    make(<config>,
         active: object["active"],
         workspace-directory: workspace-dir)
  end
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

define function update-active-packages (conf :: <config>)
  // TODO: clone active packages if directory doesn't exist.
end;

// Update dep packages if needed.
define function update-deps (conf :: <config>)
  for (pkg-name in conf.active-package-names)
    let pkg = pkg/read-package-file(active-package-file(conf, pkg-name));
    // TODO: in a perfect world this wouldn't install any deps that
    // are also active packages. It doesn't cause a problem though,
    // as long as the registry points to the right place.
    pkg/install-deps(pkg);
  end;
end;

// Create/update a single registry directory having an entry for each
// library in each active package and all transitive dependencies.
define function update-registry (conf :: <config>)
  // TODO: This uses the same shortcut as in update-deps.
  let cat = pkg/load-catalog();
  let pkgs = make(<istr-map>);
  for (pkg-name in conf.active-package-names)
    let pkg = pkg/find-package(cat, pkg-name, pkg/$latest);
    if (pkg)
      update-registry-for-package(conf, pkg, #f, #t);
      pkg/do-resolved-deps(pkg, curry(update-registry-for-package, conf));
    else
      format-out("Active package %s not found in catalog; not creating registry"
                   " files for its deps.\n", pkg);
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
  let pkg-dir = if (active-package?(conf, pkg.pkg/name))
                  active-package-directory(conf, pkg.pkg/name)
                else
                  pkg/source-directory(pkg)
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
                do-directory(doit, subdirectory-locator(dir, name));
              end;
          end;
        end;
  do-directory(doit, pkg-dir);
end;

define function update-registry-for-lid
    (conf :: <config>, lid-path :: <file-locator>)
  let lib-name = library-from-lid(lid-path);
  // TODO: I suspect the best thing is to write all registry files in
  // the platform-specific directory for the current architecture
  // rather than trying to figure out whether they should go in
  // "/generic/" or not. But for now this only works with generic
  // libraries.
  let generic = subdirectory-locator(conf.registry-directory, "generic");
  let reg-file = merge-locators(as(<file-locator>, lib-name), generic);
  ensure-directories-exist(generic);
  with-open-file(stream = reg-file, direction: #"output", if-exists?: #"overwrite")
    format(stream, "abstract:/" "/dylan/%s\n", // Split string to work around dylan-mode bug.
           relative-locator(lid-path, conf.workspace-directory));
  end;
end;

define function library-from-lid (path :: <file-locator>) => (library-name :: <str>)
  with-open-file(stream = path)
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
