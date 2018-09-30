Module: dylan-user

define library pacman-test
  use common-dylan;
  use io,
    import: { streams };
  use json;
  use pacman;
  use strings;
  use system,
    import: { file-system, operating-system };
  use testworks;
end;

define module pacman-test
  use common-dylan,
    rename: { <object> => <any>,
              <boolean> => <bool>,
              <integer> => <int>,
              <sequence> => <seq>,
              <string> => <str>,

              <table> => <map>,
              <string-table> => <str-map>,
              <case-insensitive-string-table> => <istr-map>,

              concatenate => concat };
  use file-system,
    import: { file-exists?, temp-directory };
  use json;
  use operating-system,
    import: { environment-variable-setter };
  use %pacman;
  use pacman;
  use strings,
    import: { whitespace? };
  use streams,
    import: { with-input-from-string, with-output-to-string };
  use testworks;
end;
