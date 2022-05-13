Module: dylan-user

define library dylan-tool-lib
  use collections,
    import: { table-extensions };
  use command-line-parser;
  use dylan,
    import: { dylan-extensions };
  use io,
    import: { format, format-out, print, standard-io, streams };
  use json;
  use logging;
  use regular-expressions;
  use strings;
  use system,
    import: { date, file-system, locators, operating-system };
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };

  export
    dylan-tool-lib,
    pacman,
    %pacman,
    workspaces;
end library dylan-tool-lib;

define module pacman
  export
    catalog,
    dylan-directory,            // $DYLAN or $HOME/dylan or /opt/dylan
    <catalog-error>,

    <catalog>,
    catalog-directory,
    find-package,
    find-package-release,
    validate-catalog,
    write-package-file,

    <package>,
    package-name,
    package-releases,
    package-description,
    package-contact,
    package-category,
    package-keywords,
    package-locator,

    <package-error>,
    download,
    install,
    install-deps,
    installed-versions,
    installed?,
    package-directory,
    release-directory,
    source-directory,
    load-dylan-package-file,
    load-all-catalog-packages,
    load-catalog-package,

    <release>,
    release-dependencies,
    release-dev-dependencies,
    release-license,
    // TODO:
    // release-license-url,
    release-url,
    release-to-string,
    release-version,
    publish-release,

    <dep>,
    <dep-vector>,
    dep-to-string, string-to-dep,
    dep-version,
    resolve-deps,
    resolve-release-deps,

    <version>,
    $latest,
    <semantic-version>,
    version-major,
    version-minor,
    version-patch,
    <branch-version>,
    version-branch;
end module pacman;

define module %pacman
  use date,
    import: { current-date, <duration> };
  use file-system,
    import: { delete-directory,
              directory-contents,
              directory-empty?,
              do-directory,
              ensure-directories-exist,
              file-property,
              <file-system-error>,
              <file-does-not-exist-error>,
              <file-system-file-locator>,
              <pathname>,
              with-open-file };
  use format,
    import: { format,
              format-to-string };
  use format-out;
  use json,
    import: { parse-json => json/parse,
              encode-json => json/encode,
              print-json => json/print,
              do-print-json => json/do-print,
              <json-error> => json/<error> };
  use locators,
    import: { <directory-locator>,
              <file-locator>,
              <locator>,
              locator-name,
              merge-locators,
              subdirectory-locator };
  use logging;
  use operating-system,
    import: { environment-variable => os/getenv,
              run-application => os/run };
  use print,
    import: { print, print-object, printing-object, *print-escape?* };
  use regular-expressions,
    prefix: "re/",
    rename: { <regex> => <regex>,
              regex-parser => regex-parser,  // #:regex:".*"
              compile-regex => re/compile,
              regex-pattern => re/pattern,
              regex-search => re/search,
              regex-search-strings => re/search-strings,
              match-group => re/group };
  use streams,
    import: { read-to-end, <stream>, with-output-to-string, write };
  use strings;
  use uncommon-dylan,
    exclude: { format-out, format-to-string };
  use uncommon-utils,
    import: { elt, iff, <singleton-object>, value-sequence };

  use pacman, export: all;

  // For the test suite.
  export
    $dylan-env-var,
    <dep-conflict>,
    <dep-error>,
    <latest>,
    add-release,
    cache-package,
    cached-package,
    catalog-package-cache,
    find-release,
    max-release,
    string-parser,                 // #string:...
    string-to-version, version-to-string;
end module %pacman;

define module workspaces
  use dylan-extensions,
    import: { address-of };
  use file-system,
    prefix: "fs/";
  use format,
    import: { format, format-to-string };
  use format-out;
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
  use strings;
  use uncommon-dylan,
    exclude: { format-to-string };
  use uncommon-utils,
    import: { err, iff, inc!, slice };

  export
    $dylan-package-file-name,
    load-workspace,
    <workspace>,
      active-package-directory,
      active-package-file,
      active-package?,
      workspace-active-packages,
      workspace-directory,
      find-workspace-file,
      workspace-default-library-name,
    new,
    update,
    <workspace-error>,
    find-library-names;
end module workspaces;

define module dylan-tool-lib
  use command-line-parser;
  use file-system,
    prefix: "fs/";
  use format,
    import: { format, format-to-string };
  use format-out;
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
  use logging;
  use operating-system,
    prefix: "os/",
    rename: { run-application => os/run };
  use pacman,
    prefix: "pm/";
  use regular-expressions,
    import: { regex-parser },      // #regex:"..."
    rename: { compile-regex => re/compile,
              regex-pattern => re/pattern,
              regex-search => re/search,
              regex-search-strings => re/search-strings };
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
  use strings;
  use uncommon-dylan,
    exclude: { format-to-string };
  use uncommon-utils,
    import: { err, iff, inc!, slice };
  use workspaces,
    prefix: "ws/";

  export
    dylan-tool-command-line;
end module dylan-tool-lib;
