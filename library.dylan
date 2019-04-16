module: dylan-user

define library workspaces
  use collections,
    import: { table-extensions };
  use io,
    import: { format, standard-io, streams };
  use json;
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
              locator-directory,
              locator-name,
              locator-path,
              merge-locators,
              relative-locator,
              subdirectory-locator };
  use operating-system,
    prefix: "os/";
  use pacman,
    prefix: "pm/";
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
    import: { lowercase,
              starts-with?,
              ends-with?,
              string-equal? => str=,
              string-equal-ic? => istr=,
              strip };
  use uncommon-dylan;
  use uncommon-utils,
    import: { err, iff, inc!, slice };

  export
    <workspace>,
    configure,
    new,
    update,
    workspace-file,
    <workspace-error>;
end module workspaces;
