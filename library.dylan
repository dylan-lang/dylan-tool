Module: dylan-user

define library dylan-tool
  use command-line-parser;
  use io,
    import: { format-out };
  use pacman;
  use uncommon-dylan;
end;

define module dylan-tool
  use command-line-parser,
    import: { <command-line-parser> => cli/<parser>,
              make-command-line-parser => cli/make-parser,
              };
  use format-out,
    import: { format-out, format-err };
  use pacman,
    prefix: "pkg/";
  use uncommon-dylan;
  use uncommon-utils;
end;
