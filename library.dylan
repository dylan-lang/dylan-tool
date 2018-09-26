Module: dylan-user
Synopsis: Dylan package manager

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
  use common-dylan;
  use file-system,
    import: { with-open-file };
  use json,
    import: { parse-json, encode-json };
  use locators,
    import: { <directory-locator>, <physical-locator>, merge-locators, subdirectory-locator };
  use operating-system,
    import: { environment-variable, run-application };
  use regular-expressions,
    import: { <regex>, compile-regex, regex-pattern, regex-search-strings };
  use simple-format,
    import: { format-out, format-to-string };
  use streams,
    import: { read-to-end };
  use strings,
    import: { starts-with?, string-equal-ic? };
  use table-extensions,
    import: { table, <case-insensitive-string-table> };
  use uncommon-dylan,
    import: { <singleton-object> };

  use pacman, export: all;

  // For the test suite.
  export
    read-json-catalog,
    write-json-catalog,
    version-to-string;
end module %pacman;
