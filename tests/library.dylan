Module: dylan-user

define library pacman-test
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
end;

define module pacman-test
  use file-system,
    import: { delete-directory,
              file-exists?,
              <file-system-file-locator>,
              temp-directory };
  use format,
    import: { format-to-string };
  use json;
  use locators,
    import: { merge-locators,
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
end;
