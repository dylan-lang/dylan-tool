Module: dylan-user
Synopsis: Dylan package manager

// Note that in this project I'm trying out a naming style that is
// less verbose than usual, including renaming some of the basic Dylan
// types and functions.

define library pacman
  use common-dylan;
  use io,
    import: { format, format-out, print, streams };
  use json;
  use logging;
  use regular-expressions;
  use strings;
  use system,
    import: { date, file-system, locators, operating-system, threads };
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };
  export
    pacman,
    %pacman;                    // For the test suite.
end library pacman;

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
    read-package-file,
    load-all-packages,
    load-package,

    <release>,
    release-deps,
    release-license,
    // TODO:
    // release-license-url,
    release-url,
    release-to-string,
    release-version,

    <dep>,
    <dep-vector>,
    dep-to-string, string-to-dep,
    dep-version,
    resolve-deps,

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
  use format-out,
    import: { format-out,
              force-out };
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
  use strings,
    import: { decimal-digit?,
              ends-with?,
              find-substring,
              lowercase,
              starts-with?,
              string-equal-ic? => istring=,
              string-less-ic? => istring<,
              strip };
  use threads,
    import: { dynamic-bind };
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
