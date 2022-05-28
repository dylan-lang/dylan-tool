Module: dylan-user
Synopsis: dylan-tool executable


define library dylan-tool
  use common-dylan;
  use command-line-parser;
  use dylan-tool-lib;
  use io;
  use logging;
  use system;
end;

define module dylan-tool
  use common-dylan;
  use command-line-parser;
  use dylan-tool-lib;
  use format-out;
  use logging;
  use operating-system, prefix: "os/";
  use shared;
end;
