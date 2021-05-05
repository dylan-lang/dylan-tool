Module: dylan-user

define library dylan-tool
  use command-line-parser;
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
  use workspaces;
end;

define module dylan-tool
  use command-line-parser;
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
    prefix: "os/",
    rename: { run-application => os/run };
  use pacman,
    prefix: "pm/";
  use regular-expressions,
    import: { regex-parser },      // #regex:"..."
    rename: { regex-search-strings => re/search-strings };
  use standard-io,
    import: { *standard-output* => *stdout*,
              *standard-error* => *stderr* };
  use streams,
    import: { <string-stream>,
              force-output => flush,
              read-line,
              read-to-end,
              stream-contents,
              write };
  use strings,
    import: { lowercase,
              starts-with?,
              ends-with?,
              string-equal? => str=,
              string-equal-ic? => istr=,
              strip,
              whitespace? };
  use uncommon-dylan,
    exclude: { format-to-string };
  use uncommon-utils,
    import: { err, iff, inc!, slice };
  use workspaces,
    prefix: "ws/";
end module dylan-tool;
