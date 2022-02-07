Module: converter

// Convert from the monolithic file format to the Cargo-like format with one
// entry per package and a more scalable directory structure. At the same time,
// some attributes are moved from <package> to <release> since it is possible
// for them to change with each release.

define function main
    (name :: <string>, arguments :: <vector>)
  if (arguments.size ~= 1)
    error("Usage: converter <root-directory>");
  end;
  let root = as(<directory-locator>, arguments[0]);
  let old-path = merge-locators(as(<file-locator>, "catalog.json"), root);
  let v1-directory = subdirectory-locator(root, "v1");
  format-out("Old catalog: %s\n", old-path);
  with-open-file(stream = old-path)
    for (attributes keyed-by name in parse-json(stream))
      let file = package-locator(v1-directory, name);
      ensure-directories-exist(file);
      with-open-file (out = file,
                      direction: #"output",
                      if-does-not-exist: #"create")
        print-json(transform-package(name, attributes), out,
                   indent: 2, sort-keys?: #t);
      end;
    end for;
  end;
end function;

define function transform-package
    (name :: <string>, t :: <table>) => (out :: <table>)
  // let stream = make(<string-stream>, direction: #"output");
  // print-json(t, stream, indent: 2, sort-keys?: #t);
  // format-out("transform-package(%=, %s)\n", name, stream-contents(stream));
  // force-out();
  let license = t["license-type"];
  let description = element(t, "description", default: #f) | t["summary"];
  let out = make(<string-table>);
  out["name"] := name;
  out["description"] := description;
  out["contact"] := t["contact"];
  out["category"] := t["category"];
  out["keywords"] := t["keywords"];
  let releases = make(<stretchy-vector>);
  for (dict keyed-by vstring in t["releases"])
    let r = make(<string-table>);
    r["version"] := vstring;
    r["deps"] := dict["deps"];
    r["url"] := dict["location"];
    r["license"] := license;
    add!(releases, r);
  end;
  local method version-> (t1, t2)
          let v1 = string-to-version(t1["version"]);
          let v2 = string-to-version(t2["version"]);
          v2 > v1
        end;
  sort!(releases, test: version->);
  out["releases"] := releases;
  out
end function;

define method package-locator
    (root :: <directory-locator>, name :: <string>) => (file :: <file-locator>)
  let dir
    = select (name.size)
        1 => subdirectory-locator(root, "1");
        2 => subdirectory-locator(root, "2");
        otherwise =>
          subdirectory-locator(subdirectory-locator(root, copy-sequence(name, end: 2)),
                               copy-sequence(name, start: 2, end: min(4, name.size)))
      end;
  merge-locators(as(<file-locator>, name), dir)
end method;

main(application-name(), application-arguments())
