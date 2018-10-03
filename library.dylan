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
  export
    <catalog>,
    add-package,
    all-packages,
    find-package,
    load-catalog,
    remove-package,
    store-catalog,

    <package-error>,
    download-package,
    install-package,
    installed-versions,
    installed?,

    <pkg>,
    category,
    contact,
    dependencies,
    description,
    keywords,
    license-type,
    name,
    source-url,
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

              as-lowercase => lowercase,
              concatenate => concat };
  use file-system,
    import: { directory-contents,
              directory-empty?,
              with-open-file };
  use json,
    import: { parse-json => json/parse,
              encode-json => json/encode };
  use locators,
    import: { <directory-locator>,
              <physical-locator>,
              locator-name,
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
    import: { format-out => printf,
              format-to-string => sprintf };
  use streams,
    import: { read-to-end };
  use strings,
    import: { starts-with?, string-equal-ic? };
  use table-extensions,
    import: { table,
              <case-insensitive-string-table> => <istr-map> };
  use uncommon-dylan,
    import: { <singleton-object>, value-sequence };

  use pacman, export: all;

  // For the test suite.
  export
    <dep-vec>,
    %find-package,
    package-map,
    str-parser,                 // #str:...

    string-to-version, version-to-string,
    string-to-dep, dep-to-string,

    read-json-catalog,
    write-json-catalog;
end module %pacman;
