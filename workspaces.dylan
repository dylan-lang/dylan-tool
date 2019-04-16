module: workspaces
synopsis: Manage developer workspaces

// TODO:
// * Remove redundancy in 'update' command. It processes (shared?) dependencies
//   and writes registry files multiple times.
// * Display the number of registry files updated and the number unchanged.
//   It gives reassuring feedback that something went right when there's no
//   other output.

// The class of errors explicitly signalled by this module.
define class <workspace-error> (<simple-error>)
end;

define function workspace-error
    (format-string :: <string>, #rest args)
  error(make(<workspace-error>,
             format-string: format-string,
             format-arguments: args));
end;

define function print (format-string, #rest args)
  apply(format, *stdout*, format-string, args);
  write(*stdout*, "\n");
  // OD doesn't currently have an option for flushing output after \n.
  flush(*stdout*);
end;

// Whether to display more verbose informational messages.
// May be changed via `configure(verbose?: v)`.
define variable *verbose?* :: <bool> = #f;

define function vprint (format-string, #rest args)
  if (*verbose?*)
    apply(print, format-string, args);
  end;
end;

define variable *debug?* :: <bool> = #f;

define function debug (format-string, #rest args)
  *debug?* & apply(print, concat("*** ", format-string), args)
end;

ignorable(debug);

// Configure options for this package.  If `verbose?` is true, output
// more informational messages.
define function configure (#key verbose? :: <bool>, debug? :: <bool>) => ()
  *verbose?* := verbose?;
  *debug?* := debug?;
end;

define constant $workspace-file = "workspace.json";


define function str-parser (s :: <string>) => (s :: <string>) s end;

// Pulled out into a constant because it ruins code formatting.
define constant $workspace-file-format-string = #:str:[{
    "active": {
%s
    }
}
];

// Create a new workspace named `name` with active packages
// `pkg-names`.
define function new (name :: <string>, pkg-names :: <seq>,
                     #key parent-directory :: <directory-locator> = fs/working-directory())
  if (workspace-file(directory: parent-directory))
    workspace-error("You appear to already be in a workspace directory: %s",
                    workspace-file);
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
           join(pkg-names, ",\n", key: curry(format-to-string, "        %=: {}")));
  end;
  print("Wrote workspace file to %s.", ws-path);
end;

// Update the workspace based on the workspace config or signal an error.
define function update ()
  let ws = load-workspace($workspace-file);
  print("Workspace directory is %s.", ws.workspace-directory);
  update-active-packages(ws);
  update-active-package-deps(ws);
  update-registry(ws);
end;

// <workspace> holds the parsed workspace configuration, and is the one object
// that knows the layout of the workspace directory:
//       workspace/
//         _build
//         active-package-1/
//         active-package-2/
//         registry/
define class <workspace> (<object>)
  constant slot active-packages :: <istring-table>,
    required-init-keyword: active:;
  constant slot workspace-directory :: <directory-locator>,
    required-init-keyword: workspace-directory:;
end;

define function load-workspace (filename :: <string>) => (w :: <workspace>)
  let path = workspace-file();
  if (~path)
    workspace-error("Workspace file not found."
                      " Current directory isn't under a workspace directory?");
  end;
  fs/with-open-file(stream = path, if-does-not-exist: #"signal")
    let object = json/parse(stream, strict?: #f, table-class: <istring-table>);
    if (~instance?(object, <table>))
      workspace-error("Invalid workspace file %s, must be a single JSON object", path);
    elseif (~element(object, "active", default: #f))
      workspace-error("Invalid workspace file %s, missing required key 'active'", path);
    elseif (~instance?(object["active"], <table>))
      workspace-error("Invalid workspace file %s, the 'active' element must be a map"
                        " from package name to {...}.", path);
    end;
    make(<workspace>,
         active: object["active"],
         workspace-directory: locator-directory(path))
  end
end;

// Search up from `directory` to find `$workspace-file`. If `directory` is not
// supplied it defaults to the current working directory.
define function workspace-file
    (#key directory :: <directory-locator> = fs/working-directory())
 => (file :: false-or(<file-locator>))
  if (~root-directory?(directory))
    let path = merge-locators(as(fs/<file-system-file-locator>, $workspace-file),
                              directory);
    if (fs/file-exists?(path))
      path
    else
      locator-directory(directory) & workspace-file(directory: locator-directory(directory))
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

define function active-package-names (ws :: <workspace>) => (names :: <seq>)
  key-sequence(ws.active-packages)
end;

define function active-package-directory
    (ws :: <workspace>, pkg-name :: <string>) => (d :: <directory-locator>)
  subdirectory-locator(ws.workspace-directory, pkg-name)
end;

define function active-package-file
    (ws :: <workspace>, pkg-name :: <string>) => (f :: <file-locator>)
  merge-locators(as(<file-locator>, "pkg.json"),
                 active-package-directory(ws, pkg-name))
end;

define function active-package? (ws :: <workspace>, pkg-name :: <string>) => (_ :: <bool>)
  member?(pkg-name, ws.active-package-names, test: istr=)
end;

define function registry-directory (ws :: <workspace>) => (d :: <directory-locator>)
  subdirectory-locator(ws.workspace-directory, "registry")
end;

// Download active packages into the workspace directory if the
// package directories don't already exist.
define function update-active-packages (ws :: <workspace>)
  for (attrs keyed-by pkg-name in ws.active-packages)
    // Download the package if necessary.
    let pkg-dir = active-package-directory(ws, pkg-name);
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
        print("         If this is a new or private project then this is normal.");
        print("         Create a pkg.json file for it and run update again to update deps.");
      end;
    end;
  end;
end;

// Update dep packages if needed.
define function update-active-package-deps (ws :: <workspace>)
  for (pkg-name in ws.active-package-names)
    // Update the package deps.
    let pkg = find-active-package(ws, pkg-name);
    if (pkg)
      print("Installing deps for package %s.", pkg-name);
      // TODO: in a perfect world this wouldn't install any deps that
      // are also active packages. It doesn't cause a problem though,
      // as long as the registry points to the right place.
      pm/install-deps(pkg /* , skip: ws.active-package-names */);
    else
      print("WARNING: No package definition found for active package %s."
              " Not installing deps.", pkg-name);
    end;
  end;
end;

define function find-active-package
    (ws :: <workspace>, pkg-name :: <string>) => (p :: false-or(pm/<pkg>))
  let path = active-package-file(ws, pkg-name);
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
define function update-registry (ws :: <workspace>)
  for (pkg-name in ws.active-package-names)
    let pkg = find-active-package(ws, pkg-name);
    if (pkg)
      let pkg-dir = active-package-directory(ws, pkg-name);
      update-registry-for-directory(ws, pkg-dir);
      pm/do-resolved-deps(pkg, curry(update-registry-for-package, ws));
    else
      print("WARNING: No package definition found for active package %s."
              " Not creating registry files.", pkg-name);
    end;
  end;
end;

// Dig around in each `pkg`s directory to find the libraries it
// defines and create registry files for them.
define function update-registry-for-package (ws, pkg, dep, installed?)
  if (~installed?)
    workspace-error("Attempt to update registry for dependency %s, which"
                      " is not yet installed. This may be a bug.",
                    pm/package-name(dep));
  end;
  let pkg-dir = if (active-package?(ws, pkg.pm/name))
                  active-package-directory(ws, pkg.pm/name)
                else
                  pm/source-directory(pkg)
                end;
  update-registry-for-directory(ws, pkg-dir);
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
define function update-registry-for-directory (ws :: <workspace>, pkg-dir :: <directory-locator>)
  let lib2lid = find-libraries(pkg-dir);
  // For each library, write a LID if there's one explicitly for this platform,
  // or there's one with no Platforms: specified at all.
  let platform = as(<string>, os/$platform-name);
  for (lids keyed-by lib in lib2lid)
    let candidates = #();
    block (done)
      for (lid in lids)
        if (lid-has-platform?(lid, platform)) // TODO: rename to lid-has-platform?.
          candidates := list(lid);
          done();
        elseif (~element(lid, #"platforms", default: #f))
          candidates := pair(lid, candidates);
        end;
      end;
    end block;
    select (candidates.size)
      0 => #f;  // Nothing for this platform.
      1 => update-registry-for-lid(ws, candidates[0]);
      otherwise =>
        print("WARNING: For library %s multiple .lid files apply to platform %s.\n"
                "  %s\nRegistry will point to the first one, arbitrarily.",
              lib, platform,
              join(candidates, "\n  ", key: method (lid)
                                              as(<string>, lid[$path-key])
                                            end));
        update-registry-for-lid(ws, candidates[0]);
    end select;
  end for;
end function;

define function find-libraries (pkg-dir :: <directory-locator>) => (lib2lid :: <istring-table>)
  let lib2lid = make(<istring-table>);  // library-name => list(lid-data)
  local method parse-lids (dir, name, type)
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
                fs/do-directory(parse-lids, subdir);
              end;
            #"link" => #f;
          end;
        end;
  fs/do-directory(parse-lids, pkg-dir);
  lib2lid
end function;

define function git-submodule? (dir :: <directory-locator>) => (_ :: <bool>)
  let dot-git = merge-locators(as(<file-locator>, ".git"), dir);
  fs/file-exists?(dot-git)
end;

define function update-registry-for-lid (ws :: <workspace>, lid :: <table>)
  let lid-path :: <file-locator> = lid[$path-key];
  let platform = as(<string>, os/$platform-name);
  let directory = subdirectory-locator(ws.registry-directory, platform);
  // The registry file must be written in lowercase so that on unix systems the
  // compiler can find it.
  let lib = lowercase(lid[#"library"][0]);
  let reg-file = merge-locators(as(<file-locator>, lib), directory);
  let relative-path = relative-locator(lid-path, ws.workspace-directory);
  let new-content = format-to-string("abstract:/" "/dylan/%s\n", relative-path);
  let old-content = file-content(reg-file);
  if (new-content ~= old-content)
    fs/ensure-directories-exist(reg-file);
    fs/with-open-file(stream = reg-file, direction: #"output", if-exists?: #"overwrite")
      write(stream, new-content);
    end;
    print("Wrote %s (%s)", reg-file, lid-path);
  end;
end function;

define function lid-has-platform? (lid :: <table>, platform :: <string>) => (b :: <bool>)
  let platforms = element(lid, #"platforms", default: #[]);
  member?(platform, platforms, test: istr=)
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

define constant $keyword-line-regex = #:regex:"^([a-zA-Z0-9-]+):[ \t]+(.+)$";

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
            // TODO: can as(<symbol>) err?  I should just use strings and ignore case.
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
    workspace-error("LID file %s has no Library: property.", path);
  end;
  if (empty?(lid-files(lid)))
    vprint("LID file %s has no Files: property.", path);
  end;
  lid
end function;

define function lid-files (lid :: <table>) => (files :: <seq>)
  element(lid, #"files", default: #f)
  | begin
      let sub = element(lid, #"LID", default: #f);
      (sub & element(sub, #"files", default: #f))
        | #[]
    end
end;
