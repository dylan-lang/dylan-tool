Module: dylan-user
Synopsis: Dylan package manager

// Note that in this project I'm trying out a naming style that is
// less verbose than usual, including renaming some of the basic Dylan
// types and functions. If it works out maybe I'll make an alternative
// module to common-dylan called "brevity".

define library pacman
  use common-dylan,
    import: { common-dylan, simple-format };
  use collections,
    import: { table-extensions };
  use system,
    import: { file-system, locators, operating-system };
  use io,
    import: { streams };
  use json;
  use regular-expressions;
  use strings;
  use uncommon-dylan;
  export
    pacman,
    %pacman;                    // For the test suite.
end library pacman;

define module pacman
  // Catalog
  export
    <catalog>,
    package-groups,
    add-package,
    all-packages,
    find-package,
    load-catalog,
    remove-package,
    store-catalog;

  // Packages
  export
    download-package,
    install-package,

    <pkg>,
    dependencies,
    group,
    source-url,

    <pkg-group>,
    category,
    contact,
    description,
    keywords,
    name,
    license-type,
    packages,
    synopsis,
    
    <dep>,
    package-name,
    version,

    <version>,
    $latest,
    major,
    minor,
    patch;
end module pacman;

define module %pacman
  use common-dylan,
    rename: { <object> => <any>,
              <boolean> => <bool>,
              <integer> => <int>,
              <sequence> => <seq>,
              <string> => <str>,

              <table> => <map>,
              <string-table> => <str-map>,
              <case-insensitive-string-table> => <istr-map>,

              concatenate => concat };
  use file-system,
    import: { with-open-file };
  use json,
    import: { parse-json => json/parse,
              encode-json => json/encode };
  use locators,
    import: { <directory-locator>,
              <physical-locator>,
              merge-locators,
              subdirectory-locator };
  use operating-system,
    import: { environment-variable => os/getenv,
              run-application => os/run };
  use regular-expressions,
    import: { <regex>,
              compile-regex => re/compile,
              regex-pattern => re/pattern,
              regex-search-strings => re/search-strings };
  use simple-format,
    import: { format-out, format-to-string };
  use streams,
    import: { read-to-end };
  use strings,
    import: { starts-with?, string-equal-ic? };
  use table-extensions,
    import: { table,
              <case-insensitive-string-table> => <istr-map> };
  use uncommon-dylan,
    import: { <singleton-object> };

  use pacman, export: all;

  // For the test suite.
  export
    %find-package,
    str-parser,                 // #str:...

    string-to-version,
    version-to-string,

    read-json-catalog,
    write-json-catalog;
end module %pacman;
