Module: %workspaces
Synopsis: Scan for LID files and generate a registry


define class <registry-error> (<workspace-error>)
end;

//// REGISTRY

// Keys used to lookup values in a parsed LID file.
// TODO: use 'define enum' in uncommon-dylan
define constant $platforms-key = #"platforms";
define constant $files-key = #"files";
define constant $library-key = #"library";
define constant $lid-key = #"lid";
define constant $origin-key = #"origin";
define constant $idl-file-key = #"idl-file";
define constant $prefix-key = #"prefix";

// A <registry> knows how to find and parse LID files and write registry files
// for them.
define class <registry> (<object>)

  // The directory containing the "registry" directory, where files will be written.
  constant slot root-directory :: <directory-locator>,
    required-init-keyword: root-directory:;

  // A map from library names to sequences of <lid>s that define the library.
  // (A library with platform-specific definitions may have multiple lids.)
  constant slot lids-by-library :: <istring-table> = make(<istring-table>);

  // A map from full absolute pathname to the associated <lid>.
  constant slot lids-by-pathname :: <istring-table> = make(<istring-table>);

  // This is a hack to prevent logging warning messages multiple times.  I
  // could probably have avoided this if I'd written the code in a more
  // functional style rather than mutating the registry everywhere, but at this
  // point it would require a big rewrite: find all lids for all active
  // packages and dependencies without generating any warnings, then iterate
  // over the library=>lid map deciding which files to write and logging
  // warnings once for a given library.
  constant slot updated-libraries :: <istring-table> = make(<istring-table>);

  // Libraries that have no LID file for the requested platform.
  constant slot libraries-with-no-lid = make(<stretchy-vector>);
  slot num-files-written = 0;
end class;

define function has-lid?
    (registry :: <registry>, path :: <file-locator>) => (_ :: <bool>)
  element(registry.lids-by-pathname, as(<string>, path), default: #f) & #t
end function;

// Find a <lid> in `registry` that was parsed from `path`.
define function lid-for-path
    (registry :: <registry>, path :: <file-locator>)
 => (lid :: false-or(<lid>))
  element(registry.lids-by-pathname, as(<string>, path), default: #f)
end function;

define function add-lid
    (registry :: <registry>, lid :: <lid>) => ()
  let library-name = lid-value(lid, $library-key);
  if (library-name)
    let v = element(registry.lids-by-library, library-name, default: #f);
    v := v | make(<stretchy-vector>);
    add-new!(v, lid);
    registry.lids-by-library[library-name] := v;
  end;
  registry.lids-by-pathname[as(<string>, lid.lid-locator)] := lid;
end function;

// Return a registry file locator for the library named by `lid`.
define function registry-file-locator
    (registry :: <registry>, lid :: <lid>) => (_ :: <file-locator>)
  let platform = as(<string>, os/$platform-name);
  let directory = subdirectory-locator(registry.root-directory, "registry", platform);
  // The registry file must be written in lowercase so that on unix systems the
  // compiler can find it.
  let lib = lowercase(lid-value(lid, $library-key, error?: #t));
  merge-locators(as(<file-locator>, lib), directory)
end function;


//// LID

// A <lid> holds key/value pairs from a LID file.
define class <lid> (<object>)
  constant slot lid-locator :: <file-locator>,
    required-init-keyword: locator:;

  // A map from <symbol> to sequences of <lid-value>, one for each line
  // associated with the key. Ex: #"files" => #["foo.dylan", "bar.dylan"]
  constant slot lid-data :: <table>,
    required-init-keyword: data:;

  // Sequence of other <lid>s in which this <lid> is included via the "LID:"
  // keyword.
  constant slot lid-included-in :: <seq> = make(<stretchy-vector>);
end class;

define method print-object
    (lid :: <lid>, stream :: <stream>) => ()
  format(stream, "#<lid %= %=>", lid-value(lid, $library-key), address-of(lid));
end method;

define function lid-values
    (lid :: <lid>, key :: <symbol>) => (_ :: false-or(<seq>))
  element(lid.lid-data, key, default: #f)
end function;

// The potential types that may be returned from lid-value.
define constant <lid-value> = type-union(<string>, <lid>, singleton(#f));

define function lid-value
    (lid :: <lid>, key :: <symbol>, #key error? :: <bool>) => (v :: <lid-value>)
  let items = element(lid.lid-data, key, default: #f);
  if (items & items.size = 1)
    items[0]
  elseif (error?)
    error(make(<registry-error>,
               format-string: "A single value was expected for key %=. Got %=. LID: %s",
               format-arguments: list(key, items, lid.lid-locator)))
  end
end function;

define function has-key?
    (lid :: <lid>, key :: <symbol>) => (_ :: <bool>)
  element(lid.lid-data, key, default: #f) & #t
end function;

define function has-key-value?
    (lid :: <lid>, key :: <symbol>, value :: <string>) => (_ :: <bool>)
  member?(value, lid-values(lid, key) | #[], test: string-equal-ic?)
end function;

// Return the transitive (via files included with the "LID" header) contents of
// the "Files" LID header. Files are resolved to absolute pathname strings.
define function dylan-source-files (lid :: <lid>) => (files :: <seq>)
  let files = #();
  local method dylan-source-files (lid)
          map(method (filename)
                if (~ends-with?(lowercase(filename), ".dylan"))
                  filename := concat(filename, ".dylan");
                end;
                as(<string>,
                   merge-locators(as(<file-locator>, filename),
                                  lid.lid-locator.locator-directory))
              end,
              lid-values(lid, $files-key) | #());
        end;
  local method do-lid (lid)
          files := concat(files, dylan-source-files(lid));
          for (child in lid-values(lid, $lid-key) | #())
            do-lid(child)
          end;
        end;
  do-lid(lid);
  files
end function;

// Find all the LID files in `pkg-dir` that are marked as being for the current
// platform and create registry files for the corresponding libraries. First do
// a pass over the entire directory reading lid files, then write registry
// files for the ones that aren't included in other LID files. (This avoids
// writing the same registry file twice for the same library without resorting
// to putting "Platforms: none" in LID files that are included in other LID
// files.)
define function update-for-directory
    (registry :: <registry>, dir :: <directory-locator>) => ()
  for (lid :: <lid> in update-lids(registry, dir))
    write-registry-file(registry, lid);
  end;
end function;

// Find all the LID files in `dir` that are marked as being for the current
// platform and add them to `registry`. First do a pass over the entire
// directory reading lid files, then write registry files for the ones that
// aren't included in other LID files. (This avoids writing the same registry
// file twice for the same library without resorting to putting "Platforms:
// none" in LID files that are included in other LID files.)
define function update-lids
    (registry :: <registry>, dir :: <directory-locator>,
     #key platform :: <symbol> = os/$platform-name)
 => (lids :: <seq>)
  // First find all the LIDs, then trim them down based on platform.
  let lids = find-lids(registry, dir);
  let keep = #();
  // For each library, write a LID if there's one explicitly for this platform,
  // or there's one with no platforms specified at all (as long as it isn't
  // included in another LID).
  let current-platform = as(<string>, os/$platform-name);
  let updated-libs = registry.updated-libraries;
  for (lids keyed-by library-name in registry.lids-by-library)
    let candidates = #();
    block (done)
      for (lid :: <lid> in lids)
        if (has-key-value?(lid, $platforms-key, current-platform))
          candidates := list(lid);
          done();
        elseif (~has-key?(lid, $platforms-key) & empty?(lid.lid-included-in))
          candidates := pair(lid, candidates);
        end;
      end;
    end block;
    select (candidates.size)
      0 =>
        if (~element(updated-libs, library-name, default: #f))
          // We'll display these at the end, as a group.
          add-new!(registry.libraries-with-no-lid, library-name, test: \=);
        end;
      1 =>
        write-registry-file(registry, candidates[0]);
      otherwise =>
        if (~element(updated-libs, library-name, default: #f))
          // This is a real error and should always be logged regardless of
          // the *verbose?* value.
          warn("Library %= has multiple .lid files for platform %=.\n"
                 "  %s\nRegistry will point to the first one, arbitrarily.",
               library-name, current-platform,
               join(candidates, "\n  ", key: method (lid)
                                               as(<string>, lid.lid-locator)
                                             end));
        end;
        write-registry-file(registry, candidates[0]);
    end select;
    updated-libs[library-name] := #t;
  end for;
  keep
end function;

// Descend pkg-dir parsing .lid, .hdp, or .spec files. Updates `registry`s
// internal maps.  .hdp files are (I believe) obsolecent so the .lid file is
// preferred. For .spec files the corresponding .hdp file may not exist yet so
// the table returned for it just has a #"library" key, which is enough.
define function find-lids
    (registry :: <registry>, pkg-dir :: <directory-locator>) => (lids :: <seq>)
  let lids = #();
  local
    method parse-lids (dir, name, type)
      select (type)
        #"file" =>
          let lid-path = merge-locators(as(<file-locator>, name), dir);
          if (~has-lid?(registry, lid-path))
            let comparator = if (os/$os-name == #"win32")
                               char-compare-ic
                             else
                               char-compare
                             end;
            select (name by rcurry(ends-with?, test: comparator))
              ".lid", ".hdp" =>
                let lid = ingest-lid-file(registry, lid-path);
                if (lid)
                  lids := pair(lid, lids);
                end;
              ".spec" =>
                lids := concat(lids, ingest-spec-file(registry, lid-path));
              otherwise
                => #f;
            end;
          end;
        #"directory" =>
          // Skip git submodules; their use is a vestige of pre-package manager
          // setups and it causes registry entries to be written twice. We
          // don't want the submodule library, we want the package library.
          let subdir = subdirectory-locator(dir, name);
          let subdir/git = merge-locators(as(<file-locator>, ".git"), subdir);
          if (name ~= ".git" & ~fs/file-exists?(subdir/git))
            fs/do-directory(parse-lids, subdir);
          end;
        #"link" => #f;
      end select;
    end method;
  fs/do-directory(parse-lids, pkg-dir);
  lids
end function;

// Read a <lid> from `lid-path` and store it in `registry`.  Returns the <lid>,
// or #f if nothing ingested.
define function ingest-lid-file
    (registry :: <registry>, lid-path :: <file-locator>)
 => (lid :: false-or(<lid>))
  let lid = parse-lid-file(registry, lid-path);
  if (empty?(dylan-source-files(lid)))
    warn("LID file %s has no (transitive) 'Files' property.", lid-path);
  end;
  if (skip-lid?(registry, lid))
    note("Skipping %s, preferring previous .lid file.", lid-path);
    #f
  else
    add-lid(registry, lid);
    lid
  end
end function;

// Returns true if `lid` has "hdp" extension and an existing LID in the same
// directory has "lid" extension, since the hdp files are usually automatically
// generated from the LID.
define function skip-lid?
    (registry :: <registry>, lid :: <lid>) => (skip? :: <bool>)
  if (string-equal-ic?("hdp", lid.lid-locator.locator-extension))
    let library-name = lid-value(lid, $library-key, error?: #t);
    let directory = lid.lid-locator.locator-directory;
    let existing = choose(method (x)
                            x.lid-locator.locator-directory = directory
                          end,
                          element(registry.lids-by-library, library-name, default: #[]));
    existing.size = 1
      & string-equal-ic?("lid", existing[0].lid-locator.locator-extension)
  end
end function;

// Read a CORBA spec file and store a <lid> into `registry` for each of the
// generated libraries.
define function ingest-spec-file
    (registry :: <registry>, spec-path :: <file-locator>) => (lids :: <seq>)
  let spec :: <lid> = parse-lid-file(registry, spec-path);
  let origin = lid-value(spec, $origin-key, error?: #t);
  let lids = #();
  if (string-equal-ic?(origin, "omg-idl"))
    // Generate "protocol", "skeletons", and "stubs" registries for CORBA projects.
    // The sources for these projects won't exist until generated by the build.
    // Assume .../foo.idl generates .../stubs/foo-stubs.hdp etc.
    let base-dir = locator-directory(spec-path);
    let idl-path = merge-locators(as(<file-locator>,
                                     lid-value(spec, $idl-file-key, error?: #t)),
                                  base-dir);
    let idl-name = locator-base(idl-path);
    let prefix = lid-value(spec, $prefix-key);
    for (kind in #("protocol", "skeletons", "stubs"))
      // Unsure as to why the remote-nub-protocol library doesn't need
      // "protocol: yes" in its .lid file, but what the heck, just generate a
      // registry entry for "protocol" always.
      if (kind = "protocol" | string-equal-ic?("yes", lid-value(spec, as(<symbol>, kind)) | ""))
        let lib-name = concat(prefix | idl-name, "-", kind);
        let hdp-file = as(<file-locator>, concat(prefix | idl-name, "-", kind, ".hdp"));
        let dir-name = iff(prefix,
                           concat(prefix, "-", kind),
                           kind);
        let hdp-dir = subdirectory-locator(locator-directory(idl-path), dir-name);
        let hdp-path = merge-locators(as(<file-locator>, hdp-file), hdp-dir);
        let simple-hdp-path = simplify-locator(hdp-path);
        let lid = make(<lid>,
                       locator: hdp-path,
                       data: begin
                               let t = make(<table>);
                               t[$library-key] := vector(lib-name);
                               t
                             end);
        add-lid(registry, lid);
        lids := pair(lid, lids);
      end;
    end for;
  end if;
  lids
end function;

// Write a registry file for `lid` if it doesn't exist or the content changed.
define function write-registry-file (registry :: <registry>, lid :: <lid>)
  let registry-file = registry-file-locator(registry, lid);
  let lid-file = simplify-locator(lid.lid-locator);
  // Write the absolute pathname of the LID file rather than
  // abstract://dylan/<relative-path> because the latter doesn't work reliably
  // on Windows. For example abstract://dylan/../../pkg/...  resolved to
  // C:\..\pkg\... when compiling in c:\users\cgay\dylan\workspaces\dt
  let new-content = format-to-string("%s\n", lid-file);
  let old-content = file-content(registry-file);
  if (new-content ~= old-content)
    fs/ensure-directories-exist(registry-file);
    fs/with-open-file(stream = registry-file,
                      direction: #"output",
                      if-exists?: #"replace")
      write(stream, new-content);
      registry.num-files-written := registry.num-files-written + 1;
    end;
  verbose("Wrote %s (%s)", registry-file, lid-file);
  end;
end function;

// Read the full contents of a file and return it as a string.  If the file
// doesn't exist return #f. (I thought if-does-not-exist: #f was supposed to
// accomplish this without the need for block/exception.)
define function file-content (path :: <locator>) => (text :: false-or(<string>))
  block ()
    fs/with-open-file(stream = path, if-does-not-exist: #"signal")
      read-to-end(stream)
    end
  exception (fs/<file-does-not-exist-error>)
    #f
  end
end function;

// Parse the contents of `path` into a new `<lid>` and return it. Every LID
// keyword is turned into a symbol and used as the table key, and the data
// associated with that keyword is stored as a sequence of strings, even if the
// keyword is known to allow only a single value. There is one exception: the
// "LID:" keyword is recursively parsed into a sequence of `<lid>` objects. For
// example:
//
//   #"library" => #("http")
//   #"files"   => #("foo.dylan", "bar.dylan")
//   #"LID"     => #({<lid>}, {<lid>})
define function parse-lid-file
    (registry :: <registry>, path :: <file-locator>)
 => (lid :: <lid>)
  let headers = sr/read-file-header(path);
  let lid = make(<lid>, locator: path, data: headers);
  let lid-header = element(headers, $lid-key, default: #f);
  if (lid-header)
    let sub-lids = #();
    local method filename-to-lid (filename)
            let file = as(<file-locator>, filename);
            let sub-path = merge-locators(file, locator-directory(path));
            let sub-lid = lid-for-path(registry, sub-path)
              | ingest-lid-file(registry, sub-path);
            if (sub-lid)
              sub-lids := add-new!(sub-lids, sub-lid);
              add-new!(sub-lid.lid-included-in, lid);
            end;
            sub-lid
          end;
    // ingest-lid-file can return #f, hence remove()
    headers[$lid-key] := remove(map(filename-to-lid, lid-header), #f);
  end;
  lid
end function;

define function find-library-names
    (dir :: <directory-locator>) => (names :: <seq>)
  let registry = make(<registry>, root-directory: dir);
  // It's possible for a LID included via the LID: keyword to not have a library.
  remove(map(rcurry(lid-value, $library-key),
             find-lids(registry, dir)),
         #f)
end function;

// Build a map from source file names (absolute pathname strings) to the names
// of libraries they belong to (a sequence of strings). For now we only look at
// .dylan files (i.e., the Files: header) since this is designed for use by the
// lsp-dylan library and that's what it cares about.
define function source-file-map
    (dir :: <directory-locator>) => (map :: <string-table>)
  let registry = make(<registry>, root-directory: dir);
  let file-map
    // This wouldn't be necessary if we had an <equal-table> implementation.
    // Then I'd just use locators as the keys, which is cross-platform.
    = make(if (os/$os-name == #"win32") <istring-table> else <string-table> end);
  for (lid in find-lids(registry, dir))
    let library = lid-value(lid, $library-key);
    if (library)
      for (pathname in dylan-source-files(lid))
        let libraries
          = add-new!(element(file-map, pathname, default: #()),
                     library,
                     test: string-equal-ic?);
        file-map[pathname] := libraries;
      end for;
    end if;
  end for;
  file-map
end function;
