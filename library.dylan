Module: dylan-user
Synopsis: Dylan package manager

// Note that in this project I'm trying out a naming style that is
// less verbose than usual, including renaming some of the basic Dylan
// types and functions. If it works out maybe I'll make an alternative
// module to common-dylan called "brevity".

define library pacman
  use common-dylan;
  use system,
    import: { date, file-system, locators, operating-system };
  use io,
    import: { format, format-out, print, streams };
  use json;
  use regular-expressions;
  use strings;
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
    package-synopsis,
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
              format-to-string => sprintf };
  use format-out,
    import: { format-out => printf };
  use json,
    import: { parse-json => json/parse,
              encode-json => json/encode };
  use locators,
    import: { <directory-locator>,
              <file-locator>,
              locator-name,
              merge-locators,
              subdirectory-locator };
  use operating-system,
    import: { environment-variable => os/getenv,
              run-application => os/run };
  use print,
    import: { print-object, printing-object, *print-escape?* };
  use regular-expressions,
    import: { <regex>,
              regex-parser,
              compile-regex => re/compile,
              regex-pattern => re/pattern,
              regex-search-strings => re/search-strings };
  use streams,
    import: { read-to-end, <stream>, write };
  use strings,
    import: { find-substring,
              lowercase,
              starts-with?,
              string-equal-ic? => istring= };
  use uncommon-dylan,
    rename: { \table => \tabling };
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
