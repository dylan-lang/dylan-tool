Module: dylan-user

define library dylan-tool
  use collections,
    import: { table-extensions };
  use command-line-parser;
  use io,
    import: { format-out };
  use json;
  use pacman;
  use strings;
  use system,
    import: { file-system };
  use uncommon-dylan,
    import: { uncommon-dylan,
              uncommon-utils };
end;

define module dylan-tool
  use command-line-parser,
    import: { <command-line-parser> => cli/<parser>,
              make-command-line-parser => cli/make-parser,
              };
  use file-system,
    import: { <file-system-file-locator>,
              with-open-file };
  use format-out,
    import: { format-out, format-err };
  use json,
    import: { parse-json => json/parse };
  use pacman,
    prefix: "pkg/";
  use strings,
    import: { string-equal? => str=,
              string-equal-ic? => istr= };
  use table-extensions,
    import: { <case-insensitive-string-table> => <istr-map> };
  use uncommon-dylan;
  use uncommon-utils,
    import: { elt };
end;
