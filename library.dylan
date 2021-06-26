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
    import: { date, file-system, locators, operating-system };
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };
  export
    pacman,
    %pacman;                    // For the test suite.
end library pacman;

define module pacman
  export
    load-catalog,
    <catalog-error>,

    <catalog>,
    find-package,
    find-package-release,
    package-names,

    <package>,
    package-name,
    package-releases,
    package-summary,
    package-description,
    package-contact,
    package-license-type,
    package-category,
    package-keywords,

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

    <release>,
    release-deps,
    release-location,
    release-version,
    do-resolved-deps,

    <dep>,

    <version>,
    $head,
    $latest,
    version-major,
    version-minor,
    version-patch;
end module pacman;

define module %pacman
  use date,
    import: { current-date, <duration> };
  use file-system,
    import: { delete-directory,
              directory-contents,
              directory-empty?,
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
              encode-json => json/encode };
  use locators,
    import: { <directory-locator>,
              <file-locator>,
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
    import: { <regex>,
              regex-parser,
              compile-regex => re/compile,
              regex-pattern => re/pattern,
              regex-search-strings => re/search-strings };
  use streams,
    import: { read-to-end, <stream>, with-output-to-string, write };
  use strings,
    import: { ends-with?,
              find-substring,
              lowercase,
              starts-with?,
              string-equal-ic? => istring= };
  use uncommon-dylan,
    exclude: { format-out, format-to-string };
  use uncommon-utils,
    import: { elt, iff, <singleton-object>, value-sequence };

  use pacman, export: all;

  // For the test suite.
  export
    <dep-vector>,
    all-packages,
    string-parser,                 // #string:...

    string-to-version, version-to-string,
    string-to-dep, dep-to-string,
    satisfies?,

    read-json-catalog,
    validate-catalog;
end module %pacman;
