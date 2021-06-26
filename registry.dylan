Module: workspaces
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

  // A map from library names to sequences of <lid>s.
  constant slot lids-by-library :: <istring-table> = make(<istring-table>);

  // A map from full absolute pathname to the associated <lid>.
  constant slot lids-by-pathname :: <istring-table> = make(<istring-table>);
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
  let v = element(registry.lids-by-library, library-name, default: #f);
  v := v | make(<stretchy-vector>);
  add-new!(v, lid);
  registry.lids-by-library[library-name] := v;
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
  member?(value, lid-values(lid, key) | #[], test: istring=?)
end function;

// Return the contents of the 'Files' LID keyword, including any files in
// another LID included via the "LID:" keyword.
define function lid-files (lid :: <lid>) => (files :: <seq>)
  // TODO(cgay): Technically this should go to arbitrary depth.
  // Don't want to worry about cycles right now....
  concat(lid-values(lid, $files-key) | #[],
         begin
           let sub = lid-value(lid, $lid-key);
           (sub & lid-values(sub, $files-key)) | #[]
         end)
end function;



// Find all the LID files in `pkg-dir` that are marked as being for the current
// platform and create registry files for the corresponding libraries. First do
// a pass over the entire directory reading lid files, then write registry
// files for the ones that aren't included in other LID files. (This avoids
// writing the same registry file twice for the same library without resorting
// to putting "Platforms: none" in LID files that are included in other LID
// files.)
define function update-for-directory
    (registry :: <registry>, pkg-dir :: <directory-locator>) => ()
  find-libraries(registry, pkg-dir);
  // For each library, write a LID if there's one explicitly for this platform,
  // or there's one with no Platforms: specified at all (as long as it isn't
  // included in another LID).
  let current-platform = as(<string>, os/$platform-name);
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
        log-warning("For library %=, no LID candidates for platform %=.",
                    library-name, current-platform);
      1 => write-registry-file(registry, candidates[0]);
      otherwise =>
        log-warning("For library %= multiple .lid files apply to platform %=.\n"
                      "  %s\nRegistry will point to the first one, arbitrarily.",
                    library-name, current-platform,
                    join(candidates, "\n  ", key: method (lid)
                                                    as(<string>, lid.lid-locator)
                                                  end));
        write-registry-file(registry, candidates[0]);
    end select;
  end for;
end function;

// Descend pkg-dir parsing .lid, .hdp, or .spec files. Updates `registry`s
// internal maps.  HDP files are (I believe) obsolecent so the .lid file is
// preferred. For .spec files the corresponding .hdp file may not exist yet so
// the table returned for it just has a #"library" key, which is enough.
//
// TODO(cgay): this probably assumes case sensitive filenames and will need to
// be fixed for Windows at some point.
define function find-libraries
    (registry :: <registry>, pkg-dir :: <directory-locator>) => ()
  local
    method parse-lids (dir, name, type)
      select (type)
        #"file" =>
          let lid-path = merge-locators(as(<file-locator>, name), dir);
          if (~has-lid?(registry, lid-path))
            select (name by rcurry(ends-with?, test: char-icompare))
              ".lid", ".hdp"
                => ingest-lid-file(registry, lid-path);
              ".spec"
                => ingest-spec-file(registry, lid-path);
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
end function;

// Read a <lid> from `lid-path` and store it in `registry`.  Returns a the
// <lid>, or #f if nothing ingested.
define function ingest-lid-file
    (registry :: <registry>, lid-path :: <file-locator>)
 => (lid :: false-or(<lid>))
  let lid = parse-lid-file(registry, lid-path);
  let library-name = lid-value(lid, $library-key, error?: #t);

  if (empty?(lid-files(lid)))
    log-trace("LID file %s has no 'Files' property", lid-path);
  end;

  let ext :: <string> = locator-extension(lid-path);
  let ext = ext & lowercase(ext); // Windows
  if (skip-lid?(registry, lid))
    log-info("Skipping %s, preferring previous .lid file.", lid-path);
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
  if (istring=?("hdp", lid.lid-locator.locator-extension))
    let library-name = lid-value(lid, $library-key, error?: #t);
    let directory = lid.lid-locator.locator-directory;
    let existing = choose(method (x)
                            x.lid-locator.locator-directory = directory
                          end,
                          element(registry.lids-by-library, library-name, default: #[]));
    existing.size = 1
      & istring=?("lid", existing[0].lid-locator.locator-extension)
  end
end function;

// Read a CORBA spec file and store a <lid> into `registry` for each of the
// generated libraries.
define function ingest-spec-file
    (registry :: <registry>, spec-path :: <file-locator>) => ()
  let spec :: <lid> = parse-lid-file(registry, spec-path);
  let origin = lid-value(spec, $origin-key, error?: #t);
  if (istring=?(origin, "omg-idl"))
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
      if (kind = "protocol" | istring=?("yes", lid-value(spec, as(<symbol>, kind)) | ""))
        let lib-name = concat(prefix | idl-name, "-", kind);
        let hdp-file = as(<file-locator>, concat(prefix | idl-name, "-", kind, ".hdp"));
        let dir-name = iff(prefix,
                           concat(prefix, "-", kind),
                           kind);
        let hdp-dir = subdirectory-locator(locator-directory(idl-path), dir-name);
        let hdp-path = merge-locators(as(<file-locator>, hdp-file), hdp-dir);
        let simple-hdp-path = simplify-locator(hdp-path);
        log-trace("  %s: hdp-path = %s", lib-name, hdp-path);
        log-trace("  %s: simple-hdp-path = %s", lib-name, simple-hdp-path);
        add-lid(registry, make(<lid>,
                               locator: hdp-path,
                               data: begin
                                       let t = make(<table>);
                                       t[$library-key] := vector(lib-name);
                                       t
                                     end));
      end;
    end for;
  end if;
end function;

// Write a registry file for `lid` if it doesn't exist or the content changed.
define function write-registry-file (registry :: <registry>, lid :: <lid>)
  let file = registry-file-locator(registry, lid);
  let relative-path = relative-locator(lid.lid-locator, registry.root-directory);
  let new-content = format-to-string("abstract://dylan/%s\n", relative-path);
  let old-content = file-content(file);
  if (new-content ~= old-content)
    fs/ensure-directories-exist(file);
    fs/with-open-file(stream = file, direction: #"output", if-exists?: #"overwrite")
      write(stream, new-content);
    end;
    log-info("Wrote %s (%s)", file, lid.lid-locator);
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

define constant $keyword-line-regex = #:regex:"^([a-zA-Z0-9-]+):[ \t]+(.+)$";

// Parse the contents of `path` into a new `<lid>` and return it. Every LID
// keyword is turned into a symbol and used as the table key, and the data
// associated with that keyword is stored as a vector of strings, even if it is
// known to accept only a single value. There is one exception: the keyword
// "LID:" is recursively parsed into another `<lid>` and included directly. For
// example,
//
//   #"library" => #["http"]
//   #"files"   => #["foo.dylan", "bar.dylan"]
//   #"LID"     => {<lid>}
//
// `registry` is not modified; it is only needed in order to access other,
// related LID files.
// TODO(cgay): refactor to call a new function parse-lid-text, and test that.
define function parse-lid-file
    (registry :: <registry>, path :: <file-locator>)
 => (lid :: <lid>)
  let data = make(<table>);
  let lid = make(<lid>, locator: path, data: data);
  let line-number = 0;
  let prev-key = #f;
  fs/with-open-file(stream = path)
    let line = #f;
    while (line := read-line(stream, on-end-of-stream: #f))
      inc!(line-number);
      if (strip(line) ~= ""     // tolerate blank lines
            & ~starts-with?(strip(line), "//"))
        if (starts-with?(line, " ") | starts-with?(line, "\t"))
          // Continuation line
          if (prev-key)
            let value = strip(line);
            if (~empty?(value))
              data[prev-key] := add!(data[prev-key], value);
            end;
          else
            log-trace("Skipped unexpected continuation line %s:%d", path, line-number);
          end;
        else
          // Keyword line
          let (whole, keyword, value) = re/search-strings($keyword-line-regex, line);
          if (whole)
            value := strip(value);
            // TODO: can as(<symbol>) err?  I should just use strings and ignore case.
            let key = as(<symbol>, keyword);
            if (key = $lid-key)
              // LID files may be encountered twice: once when the directory
              // traversal finds them directly and once here.
              let sub-path = merge-locators(as(<file-locator>, value), locator-directory(path));
              let sub-lid = lid-for-path(registry, sub-path);
              sub-lid := sub-lid | ingest-lid-file(registry, sub-path);
              lid.lid-data[$lid-key] := vector(sub-lid);
              add-new!(sub-lid.lid-included-in, lid);
              prev-key := #f;
            else
              data[key] := vector(value);
              prev-key := key;
            end;
          else
            log-trace("Skipped invalid syntax line %s:%d: %=", path, line-number, line);
          end;
        end;
      end;
    end while;
  end;
  lid
end function;
