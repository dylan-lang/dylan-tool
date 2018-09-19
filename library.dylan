Module: dylan-user
Synopsis: Dylan package manager

define library package-manager
  use common-dylan;
  use collections,
    import: { table-extensions };
  use system,
    import: { file-system, locators, operating-system };
  use io,
    import: { streams };
  use json;
  use regular-expressions;
  use strings;
  export
    package-manager;
end library package-manager;

define module package-manager
  use common-dylan;
  use file-system,
    import: { with-open-file };
  use json,
    import: { parse-json, encode-json };
  use locators,
    import: { <directory-locator>, subdirectory-locator };
  use operating-system,
    import: { environment-variable, run-application };
  use regular-expressions,
    import: { <regex>, compile-regex, regex-pattern, regex-search-strings };
  use simple-format,
    import: { format-to-string };
  use streams,
    import: { read-to-end };
  use strings,
    import: { starts-with? };
  use table-extensions,
    import: { table, <case-insensitive-string-table> };

  // Catalog
  export
    <catalog>,
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
    <package>,
    <version>,
    major,
    minor,
    patch;
end module package-manager;
