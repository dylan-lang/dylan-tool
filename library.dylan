Module: dylan-user
Synopsis: dylan-tool executable


define library dylan-tool
  use common-dylan;
  use command-line-parser;
  use dylan-tool-commands;
  use logging;
  use system;
end;

define module dylan-tool
  use common-dylan;
  use command-line-parser;
  use dylan-tool-commands;
  use logging;
  use operating-system, prefix: "os/";
end;
