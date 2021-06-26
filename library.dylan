module: dylan-user

define library workspaces
  use collections,
    import: { table-extensions };
  use dylan,
    import: { dylan-extensions };
  use io,
    import: { format, print, standard-io, streams };
  use json;
  use logging;
  use pacman;
  use regular-expressions;
  use strings;
  use system,
    import: { file-system, locators, operating-system };
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };
  export workspaces;
end;

define module workspaces
  use dylan-extensions,
    import: { address-of };
  use file-system,
    prefix: "fs/";
  use format,
    import: { format, format-to-string };
  use json,
    import: { parse-json => json/parse };
  use locators,
    import: { <directory-locator>,
              <file-locator>,
              <locator>,
              locator-as-string,
              locator-base,
              locator-directory,
              locator-extension,
              locator-path,
              merge-locators,
              relative-locator,
              simplify-locator,
              subdirectory-locator };
  use logging;
  use operating-system,
    prefix: "os/";
  use pacman,
    prefix: "pm/";
  use print,
    import: { print-object };
  use regular-expressions,
    import: { regex-parser },      // #:regex:"..."
    rename: { regex-search-strings => re/search-strings };
  use standard-io,
    import: { *standard-output* => *stdout*,
              *standard-error* => *stderr* };
  use streams,
    import: { force-output => flush,
              read-line,
              read-to-end,
              write };
  use strings,
    // Trying out some alternative names for these...
    import: { char-compare-ic => char-icompare,
              ends-with?,
              lowercase,
              starts-with?,
              string-equal? => string=?,
              string-equal-ic? => istring=?,
              strip };
  use uncommon-dylan,
    exclude: { format-to-string };
  use uncommon-utils,
    import: { err, iff, inc!, slice };

  export
    find-workspace,
    <workspace>,
      active-package-directory,
      active-package-file,
      active-package?,
      workspace-active-packages,
      workspace-directory,
      workspace-file,
      workspace-default-library-name,
    new,
    update,
    <workspace-error>;
end module workspaces;
