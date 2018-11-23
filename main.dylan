Module: dylan-tool

// I'm undecided whether to go forward with this tool in the long run
// or to try and use Deft, but I don't want to deal with Deft's
// problems right now so this should be a pretty simple way to get
// workspaces and packages working.

// TODO:
// * Remove redundancy in 'update' command. It processes (shared?) dependencies
//   and writes registry files multiple times.
// * Display the number of registry files updated and the number unchanged.
//   It gives reassuring feedback that something went right when there's no
//   other output.
// * The 'list' subcommand is showing a random set of packages in my ws.all
//   workspace.

define function tool-error
    (format-string :: <string>, #rest args)
  error(make(<simple-error>,
             format-string: format-string,
             format-arguments: args));
end;

define function print (format-string, #rest args)
  apply(format, *stdout*, format-string, args);
  write(*stdout*, "\n");
  // OD doesn't currently have an option for flushing output after \n.
  flush(*stdout*);
end;

// May be changed via the --verbose flag.
define variable *verbose* :: <bool> = #f;

define function vprint (format-string, #rest args)
  if (*verbose*)
    apply(print, format-string, args);
  end;
end;

define variable *debug* :: <bool> = #f;

define function debug (format-string, #rest args)
  *debug* & apply(print, concat("*** ", format-string), args)
end;

ignorable(debug);

define constant $workspace-file = "workspace.json";

define function main () => (status :: <int>)
  block (exit)
    // TODO: command parsing is ad-hoc because command-line-parser
    //       doesn't do well with subcommands. Needs improvement.
    let app = locator-name(as(<file-locator>, application-name()));
    local method usage (#key status :: <int> = 2)
            print(#str:"Usage:
%s install <pkg> <version>
    Install a package into ${DYLAN}/pkg. <version> may be a version
    number of the form 1.2.3, 'latest' to install the latest numbered
    version, or 'head'.

%s list [--all]
    List installed packages. With --all, list all packages in the
    catalog along with the latest available version. (grep is your
    friend here.)

%s new <workspace> <pkg>...
    Create a new workspace with the specified active packages. If the
    single package 'all' is specified the workspace will contain all
    packages found in the package catalog.

%s update
    Bring the current workspace up-to-date with the workspace.json file.
    Install dependencies and update the registry for any new .lid files.

Notes:
  A --verbose flag may be added (anywhere) to see more detailed output.
", app, app, app, app, app, app);
            exit(status);
          end;
    let args = application-arguments();
    if (args.size = 0
          | member?("--help", args, test: istr=)
          | member?("-h", args, test: istr=))
      usage(status: 0);
    end;
    let subcmd = args[0];
    let args = slice(args, 1, #f);
    if (member?("--debug", args, test: istr=))
      args := remove(args, "--debug", test: istr=);
      *debug* := #t;
    end;
    if (member?("--verbose", args, test: istr=))
      args := remove(args, "--verbose", test: istr=);
      *verbose* := #t;
    end;
    select (subcmd by istr=)
      "install" =>
        // Install a specific package.
        args.size = 2 | usage();
        let pkg-name = args[1];
        let vstring = args[2];
        let pkg = pm/find-package(pm/load-catalog(), pkg-name, vstring);
        if (~pkg)
          error("Package %s not found.", pkg-name);
        end;
        pm/install(pkg);
      "list" =>
        list-catalog(all?: member?("--all", args, test: istr=));
      "new" =>                  // Create a new workspace.
        args.size >= 2 | usage();
        apply(new, app, args[0], slice(args, 1, #f));
      "update" =>
        args.size = 0 | usage();
        update();        // Update the workspace based on config file.
      otherwise =>
        print("%= not recognized", subcmd);
        usage();
    end select;
    0
  exception (err :: <error>, test: method (_) ~*debug* end)
    print("Error: %s", err);
    1
  end
end function main;

// List installed package names, synopsis, versions, etc. If `all` is
// true, show all packages.
define function list-catalog (#key all? :: <bool>)
  let cat = pm/load-catalog();
  for (pkg-name in sort(pm/package-names(cat)))
    let versions = pm/installed-versions(pkg-name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let entry = pm/find-entry(cat, pkg-name);
    let latest = pm/find-package(cat, pkg-name, pm/$latest);
    let needs-update? = latest-installed & latest
                          & (pm/version(latest) ~= pm/$head)
                          & (latest-installed < pm/version(latest));
    if (all? | latest-installed)
      print("%s%s (latest: %s) - %s",
            pkg-name,
            iff(needs-update?, "*", ""),
            pm/version(latest),
            pm/synopsis(entry));
    end;
  end;
end;

define function str-parser (s :: <string>) => (s :: <string>) s end;

// Pulled out into a constant because it ruins code formatting.
define constant $workspace-file-format-string = #str:[{
    "active": {
%s
    }
}
];

define function new (app :: <string>, workspace-name :: <string>, #rest pkg-names)
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
           join(pkg-names, ",\n", key: curry(format-to-string, "        %=: {}")));
  end;
  print("Wrote workspace file to %s.", workspace-path);
  print("You may now run '%s update' in the new directory.", app);
end;

// Update the workspace based on the workspace config or signal an error.
define function update ()
  let config = load-workspace-config($workspace-file);
  print("Workspace directory is %s.", config.workspace-directory);
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
define class <config> (<object>)
  constant slot active-packages :: <istring-table>, required-init-keyword: active:;
  constant slot workspace-directory :: <directory-locator>, required-init-keyword: workspace-directory:;
end;

define function load-workspace-config (filename :: <string>) => (c :: <config>)
  let path = find-workspace-file(fs/working-directory());
  if (~path)
    error("Workspace file not found. Current directory isn't under a workspace directory?");
  end;
  fs/with-open-file(stream = path, if-does-not-exist: #"signal")
    let object = json/parse(stream, strict?: #f, table-class: <istring-table>);
    if (~instance?(object, <table>))
      error("Invalid workspace file %s, must be a single JSON object", path);
    elseif (~element(object, "active", default: #f))
      error("Invalid workspace file %s, missing required key 'active'", path);
    elseif (~instance?(object["active"], <table>))
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
    (conf :: <config>, pkg-name :: <string>) => (d :: <directory-locator>)
  subdirectory-locator(conf.workspace-directory, pkg-name)
end;

define function active-package-file
    (conf :: <config>, pkg-name :: <string>) => (f :: <file-locator>)
  merge-locators(as(<file-locator>, "pkg.json"),
                 active-package-directory(conf, pkg-name))
end;

define function active-package? (conf :: <config>, pkg-name :: <string>) => (_ :: <bool>)
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
      vprint("Active package %s exists, not downloading.", pkg-name);
    else
      let cat = pm/load-catalog();
      let pkg = pm/find-package(cat, pkg-name, pm/$head)
                  | pm/find-package(cat, pkg-name, pm/$latest);
      if (pkg)
        pm/download(pkg, pkg-dir);
      else
        print("WARNING: Skipping active package %s, not found in catalog.", pkg-name);
        print("WARNING: If this is a new or private project then this is normal.");
        print("WARNING: Create a pkg.json file for it and run update again to update deps.");
      end;
    end;
  end;
end;

// Update dep packages if needed.
define function update-active-package-deps (conf :: <config>)
  for (pkg-name in conf.active-package-names)
    // Update the package deps.
    let pkg = find-active-package(conf, pkg-name);
    if (pkg)
      print("Installing deps for package %s.", pkg-name);
      // TODO: in a perfect world this wouldn't install any deps that
      // are also active packages. It doesn't cause a problem though,
      // as long as the registry points to the right place.
      pm/install-deps(pkg /* , skip: conf.active-package-names */);
    else
      print("WARNING: No package definition found for active package %s."
              " Not installing deps.", pkg-name);
    end;
  end;
end;

define function find-active-package
    (conf :: <config>, pkg-name :: <string>) => (p :: false-or(pm/<pkg>))
  let path = active-package-file(conf, pkg-name);
  pm/read-package-file(path)
    | begin
        print("WARNING: No package found in %s, falling back to catalog.", path);
        let cat = pm/load-catalog();
        pm/find-package(cat, pkg-name, pm/$head)
          | begin
              print("WARNING: No %s HEAD version found, falling back to latest.", pkg-name);
              pm/find-package(cat, pkg-name, pm/$latest)
            end
      end
end;

// Create/update a single registry directory having an entry for each
// library in each active package and all transitive dependencies.
// This traverses package directories to find .lid files. Note that it
// assumes that .lid files that have no "Platforms:" section are
// generic, and writes a registry file for them.
define function update-registry (conf :: <config>)
  for (pkg-name in conf.active-package-names)
    let pkg = find-active-package(conf, pkg-name);
    if (pkg)
      let pkg-dir = active-package-directory(conf, pkg-name);
      update-registry-for-directory(conf, pkg-dir);
      pm/do-resolved-deps(pkg, curry(update-registry-for-package, conf));
    else
      print("WARNING: No package definition found for active package %s."
              " Not creating registry files.", pkg-name);
    end;
  end;
end;

// Dig around in each `pkg`s directory to find the libraries it
// defines and create registry files for them.
define function update-registry-for-package (conf, pkg, dep, installed?)
  if (~installed?)
    error("Attempt to update registry for dependency %s, which"
            " is not yet installed. This may be a bug.", pm/package-name(dep));
  end;
  let pkg-dir = if (active-package?(conf, pkg.pm/name))
                  active-package-directory(conf, pkg.pm/name)
                else
                  pm/source-directory(pkg)
                end;
  update-registry-for-directory(conf, pkg-dir);
end;

define constant $path-key = #"__path";

// Find all the LID files in `pkg-dir` that are marked as being for
// the current platform and create registry files for the
// corresponding libraries. First do a pass over the entire directory
// reading lid files, then write registry files for the ones that
// aren't included in other LID files. (This avoids writing the same
// registry file twice for the same library without resorting to
// putting "Platforms: none" in LID files that are included in other
// LID files.)
define function update-registry-for-directory (conf, pkg-dir)
  let lib2lid = make(<istring-table>);  // library-name => list(lid-data)
  local method doit (dir, name, type)
          select (type)
            #"file" =>
              if (ends-with?(name, ".lid"))
                let lid-path = merge-locators(as(<file-locator>, name), dir);
                let lid = parse-lid-file(lid-path);
                let libs = element(lid, #"library", default: #f);
                let lib = ~empty?(libs) & libs[0];
                if (~lib)
                  print("Skipping %s, it has no Library: line.", lid-path);
                end;
                let lids = element(lib2lid, lib, default: #[]);
                lib2lid[lib] := add(lids, lid);
              end;
            #"directory" =>
              // Skip git submodules; their use is a vestige of
              // pre-package manager setups and it causes registry
              // entries to be written twice. We don't want the
              // submodule library, we want the package library.
              let subdir = subdirectory-locator(dir, name);
              if (name ~= ".git" & ~git-submodule?(subdir))
                fs/do-directory(doit, subdir);
              end;
            #"link" => #f;
          end;
        end;
  fs/do-directory(doit, pkg-dir);

  for (lids keyed-by lib in lib2lid) // lids should never have > ~3 elements
    for (lid1 in lids)
      // Check if any of the other LIDs for this library include lid1.
      let included? = #f;
      for (lid2 in lids, while: ~included?)
        if (lid1 ~== lid2)
          let sublid = element(lid2, #"LID", default: #f);
          if (sublid & as(<string>, lid1[$path-key]) = as(<string>, sublid[$path-key]))
            included? := #t;
          end;
        end;
      end for;
      if (~included?)
        update-registry-for-lid(conf, lid1);
      end;
    end for;
  end;
end function update-registry-for-directory;

define function git-submodule? (dir :: <directory-locator>) => (_ :: <bool>)
  let dot-git = merge-locators(as(<file-locator>, ".git"), dir);
  fs/file-exists?(dot-git)
end;

define function update-registry-for-lid (conf :: <config>, lid :: <table>)
  let lid-path :: <file-locator> = lid[$path-key];
  let platform = lowercase(as(<string>, os/$platform-name));
  let lid-platforms = element(lid, #"platforms", default: #f);
  if (lid-platforms & (member?("none", lid-platforms, test: istr=)
                         | ~member?(platform, lid-platforms, test: str=)))
    vprint("Skipped, not %s: %s", platform, lid-path);
  else
    let directory = subdirectory-locator(conf.registry-directory, platform);
    let lib = lid[#"library"][0];
    let reg-file = merge-locators(as(<file-locator>, lib), directory);
    let relative-path = relative-locator(lid-path, conf.workspace-directory);
    let new-content = format-to-string("abstract:/" "/dylan/%s\n", relative-path);
    let old-content = file-content(reg-file);
    if (new-content ~= old-content)
      fs/ensure-directories-exist(reg-file);
      fs/with-open-file(stream = reg-file, direction: #"output", if-exists?: #"overwrite")
        write(stream, new-content);
      end;
      print("Wrote %s (%s)", reg-file, lid-path);
    end;
  end;
end;

// Read the full contents of a file and return it as a string.  If the
// file doesn't exist return #f. (I thought if-does-not-exist: #f was
// supposed to accomplish this without the need for block/exception.)
define function file-content (path :: <locator>) => (s :: false-or(<string>))
  block ()
    fs/with-open-file(stream = path, if-does-not-exist: #"signal")
      read-to-end(stream)
    end
  exception (e :: fs/<file-does-not-exist-error>)
    #f
  end
end;

define constant $keyword-line-regex = #regex:"^([a-zA-Z0-9-]+):[ \t]+(.+)$";

// Parse the contents of `path` into a newly created `<table>` and
// return the table.
define function parse-lid-file (path :: <file-locator>) => (lid :: <table>)
  parse-lid-file-into(path, make(<table>))
end;

// Parse the contents of `path` into `lid`. Every LID keyword is
// turned into a symbol and used as the table key, and the data
// associated with that keyword is stored as a vector of strings, even
// if it is known to accept only a single value. There is one
// exception: the keyword "LID:" is recursively parsed into another
// `<table>` and included directly. For example,
//
//   #"library" => #["http"]
//   #"files"   => #["foo.dylan", "bar.dylan"]
//   #"LID"     => {<table>}
//
// The `path` is stored in the table under the key `$path-key`.
define function parse-lid-file-into (path :: <file-locator>, lid :: <table>) => (lid :: <table>)
  lid[$path-key] := path;
  let line-number = 0;
  let prev-key = #f;
  fs/with-open-file(stream = path)
    let line = #f;
    while (line := read-line(stream, on-end-of-stream: #f))
      inc!(line-number);
      if (strip(line) ~= ""     // tolerate blank lines
            & ~starts-with?(strip(line), "/" "/"))
        if (starts-with?(line, " ") | starts-with?(line, "\t"))
          // Continuation line
          if (prev-key)
            let value = strip(line);
            if (~empty?(value))
              lid[prev-key] := add!(lid[prev-key], value);
            end;
          else
            vprint("Skipped unexpected continuation line %s:%d", path, line-number);
          end;
        else
          // Keyword line
          let (whole, keyword, value) = re/search-strings($keyword-line-regex, line);
          if (whole)
            value := strip(value);
            let key = as(<symbol>, keyword);
            if (key = #"LID")
              // Note that we parse included LIDs twice. Once when the
              // directory traversal finds them directly and once
              // here. It's not worth optimizing.
              let sub-path = merge-locators(as(<file-locator>, value), locator-directory(path));
              lid[#"LID"] := parse-lid-file-into(sub-path, make(<table>));
              prev-key := #f;
            else
              lid[key] := vector(value);
              prev-key := key;
            end;
          else
            vprint("Skipped invalid syntax line %s:%d: %=", path, line-number, line);
          end;
        end;
      end;
    end while;
  end;
  if (~element(lid, #"library", default: #f))
    tool-error("LID file %s has no Library: property.", path);
  end;
  if (empty?(lid-files(lid)))
    print("LID file %s has no Files: property.", path);
  end;
  lid
end function parse-lid-file-into;

define function lid-files (lid :: <table>) => (files :: <seq>)
  element(lid, #"files", default: #f)
  | begin
      let sub = element(lid, #"LID", default: #f);
      (sub & element(sub, #"files", default: #f))
        | #[]
    end
end;

exit-application(main());
