Module: dylan-user

define library pacman-test-suite
  use io,
    import: { format, streams };
  use json;
  use pacman;
  use strings;
  use system,
    import: { file-system, locators, operating-system };
  use testworks;
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };
end library;

define module pacman-test-suite
  use file-system,
    import: { file-exists? };
  use format,
    import: { format-to-string };
  use json;
  use locators,
    import: { <file-locator>,
              merge-locators,
              subdirectory-locator };
  use operating-system,
    import: { environment-variable-setter };
  use %pacman;
  use pacman;
  use strings,
    import: { whitespace? };
  use streams,
    import: { with-input-from-string, with-output-to-string };
  use testworks;
  use uncommon-dylan,
    exclude: { format-to-string };
end module;
