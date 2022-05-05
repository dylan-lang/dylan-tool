Module: dylan-tool
Synopsis: dylan-tool main function


define function main () => (status :: false-or(<integer>))
  // Configure logging. We use the logging module for output so we can control verbosity
  // that way.
  log-formatter(*log*) := make(<log-formatter>, pattern: "%s  %m");

  let parser = dylan-tool-command-line();
  block ()
    parse-command-line(parser, application-arguments());
    if (get-option-value(parser, "debug") & get-option-value(parser, "verbose"))
      log-level(*log*) := $trace-level;
    end;
    execute-command(parser);
  exception (err :: <abort-command-error>)
    let status = exit-status(err);
    if (status ~= 0)
      log-info("%s", err);
    end;
    status
  exception (err :: <error>)
    log-error("%s", condition-to-string(err));
    if (get-option-value(parser, "debug"))
      signal(err)
    end;
  end
end function;

os/exit-application(main() | 0);
