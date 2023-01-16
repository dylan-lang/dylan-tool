Module: dylan-user


define library dylan-tool-app
  use common-dylan;
  use command-line-parser;
  use dylan-tool;
  use io;
  use logging;
  use system;
end library;

define module dylan-tool-app
  use common-dylan;
  use command-line-parser;
  use dylan-tool;
  use format-out;
  use logging;
  use operating-system, prefix: "os/";
  use shared;
end module;
