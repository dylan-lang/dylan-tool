Module: dylan-user

define library pacman-test
  use common-dylan;
  use io, import: { streams };
  use json;
  use pacman;
  use strings;
  use testworks;
end;

define module pacman-test
  use common-dylan;
  use json;
  use %pacman;
  use pacman;
  use strings,
    import: { whitespace? };
  use streams,
    import: { with-input-from-string, with-output-to-string };
  use testworks;
end;
