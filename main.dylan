Module: dylan-tool-app
Synopsis: dylan-tool-app main function


define function main () => (status :: false-or(<integer>))
  let parser = dylan-tool-command-line();
  block ()
    parse-command-line(parser, application-arguments());
    *debug?* := get-option-value(parser, "debug");
    *verbose?* := get-option-value(parser, "verbose");
    execute-command(parser);
  exception (err :: <abort-command-error>)
    let status = exit-status(err);
    if (status ~= 0)
      format-err("Error: %s\n", err);
    end;
    status
  exception (err :: <error>)
    format-err("%s\n", condition-to-string(err));
    if (get-option-value(parser, "debug"))
      signal(err)
    end;
  end
end function;

os/exit-application(main() | 0);
