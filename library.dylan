Module: dylan-user
Synopsis: Dylan package manager

define library package-manager
  use common-dylan;
  use collections,
    import: { table-extensions };
  use system,
    import: { file-system, locators };
  use io,
    import: { streams };
  use json;
  use regular-expressions;
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
    import: { <directory-locator> };
  use regular-expressions,
    import: { <regex>, compile-regex, regex-pattern, regex-search-strings };
  use streams,
    import: { read-to-end };
  use table-extensions,
    import: { table, <case-insensitive-string-table> };

  // Catalog
  export
    <catalog>,
    <json-file-storage>,
    load-catalog,
    store-catalog;

  // Packages
  export
    <package>,
    <version>,
    major,
    minor,
    patch;
end module package-manager;
