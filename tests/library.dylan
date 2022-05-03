Module: dylan-user

define library dylan-tool-test-suite
  use common-dylan;
  use dylan-tool-commands;
  use io;
  use system;
  use testworks;
end library;

define module dylan-tool-test-suite
  use common-dylan;
  use file-system;
  use format;
  use locators;
  use operating-system;
  use pacman;
  use %pacman;
  use testworks;
  use workspaces;
end module;
