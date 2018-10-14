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
        pkg/install-package(pkg);
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
end;

define class <config> (<any>)
  constant slot active-packages :: <istr-map>, required-init-keyword: active:;
end;

define function active-package-names (conf :: <config>) => (names :: <seq>)
  key-sequence(conf.active-packages)
end;

define function load-workspace-config (filename :: <str>) => (_ :: <config>)
  // TODO: search up directory tree to find nearest workspace file.
  let path = as(<file-system-file-locator>, $workspace-file);
  with-open-file(stream = path, if-does-not-exist: #"error")
    let object = json/parse(stream, strict?: #f);
    if (~instance?(object, <map>))
      error("invalid workspace file %s, must be a single JSON object", path);
    elseif (~elt(object, "active", or: #f))
      error("invalid workspace file %s, missing required key 'active'", path);
    end;
    object["active"]
  end
end;

define function update-active-packages (conf :: <config>)
  // TODO: clone active packages if directory doesn't exist.
end;

define function update-deps (conf :: <config>)
  // TODO: as a quick way to get started this uses the catalog to find
  // dependencies. The right way is to specify the dependencies in the
  // source code of the package somewhere, e.g., a package definition
  // file or in the .lid files. That way, as the dependencies change
  // for new code they can be updated accordingly.
  let cat = pkg/load-catalog();
  for (pkg-name in active-package-names(conf))
    let pkg = pkg/find-package(cat, pkg-name, pkg/$latest);
    if (pkg)
      pkg/install-deps(pkg);
    else
      format-out("Active package %s not found in catalog; not installing its deps.\n",
                 pkg-name);
    end;
  end;
end;

// Create/update a single registry directory in the current directory
// having an entry for each library in each active package and all
// transitive dependencies.
define function update-registry (conf :: <config>)
  let cat = pkg/load-catalog();
  let pkgs = make(<istr-map>);
  for (pkg-name in conf.active-packag-names)
    let pkg = pkg/find-package(cat, pkg-name, pkg/$latest);
    if (pkg)
      pkg/do-deps(pkg, method (p)
                         let old-srcdir = elt(pkgs, p.name, #f);
                         let new-srcdir = source-directory(p);
                         if (old-srcdir & (old-srcdir ~= new-srcdir))
                           error("

exit-application(main());
