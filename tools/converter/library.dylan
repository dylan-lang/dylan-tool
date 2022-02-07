Module: dylan-user

define library converter
  use common-dylan;
  use io;
  use json;
  use pacman;
  use system;
end library;

define module converter
  use common-dylan;
  use file-system;
  use format-out;
  use json;
  use locators;
  use %pacman,
    import: { string-to-version };
  use streams;
end module;
