Module: dylan-user

define library dylan-tool-test-suite
  use common-dylan;
  use dylan-tool-lib;
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
  use shared;
  use standard-io;
  use streams;
  use testworks;
  use threads;
  use workspaces;
end module;
