Module: dylan-tool

// TODO:
// * The 'list' subcommand is showing a random set of packages in my ws.all
//   workspace.

define function print
    (format-string, #rest args)
  apply(format, *stdout*, format-string, args);
  write(*stdout*, "\n");
  // OD doesn't currently have an option for flushing output after \n.
  flush(*stdout*);
end function;

// Create the #str:"..." syntax. (Unused for now.)
//define function str-parser (s :: <string>) => (s :: <string>) s end;

/*
define command-line <dylan-tool-command-line> ()
  usage "dylan-tool [options] subcommand [options] [args]";
  help "...longer help message here...";

  option verbose? :: <boolean>,
    names: #("v", "verbose");

  subcommand install ()
    help "Install a package into ${DYLAN}/pkg.";
    option force? :: <boolean>,
      default: #t,
      help: "blah blah";
    option version :: <version>,
      default: "latest",
      help: "blah blah";
    parameter package :: <string>,
      required?: #t, // default = #t
      repeated?: #f, // default = #f
      help "A number of the form 1.2.3, 'latest' to install the latest"
              " numbered version, or 'head'.";
  subcommand list ()
    option all? :: <boolean>,
      default: #f;
end command-line;
*/
define class <install-subcommand> (<subcommand>)
  keyword name = "install";
  keyword help = "Install Dylan packages.";
end class;

define class <new-subcommand> (<subcommand>)
  keyword name = "new";
  keyword help = "Create a new workspace with the given packages.";
end class;

define class <update-subcommand> (<subcommand>)
  keyword name = "update";
  keyword help = "Bring the current workspace up-to-date with the workspace.json file.";
end class;

define class <list-subcommand> (<subcommand>)
  keyword name = "list";
  keyword help = "List installed Dylan packages.";
end class;

define class <workspace-dir-subcommand> (<subcommand>)
  keyword name = "workspace-dir";
  keyword help = "Print the pathname of the workspace directory.";
end class;

define function make-command-line-parser
    () => (p :: <command-line-parser>)
  make(<command-line-parser>,
       help: "Tool to maintain Dylan dev workspaces and installed packages.",
       options: list(make(<flag-option>,
                          name: "verbose",
                          help: "Generate more verbose output."),
                     make(<flag-option>,
                          name: "debug",
                          help: "Enter the debugger (or print a backtrace) on error.")),
       subcommands:
         list(make(<install-subcommand>,
                   options: list(make(<parameter-option>,
                                      // TODO: type: <version>
                                      names: #("version", "v"),
                                      default: "latest",
                                      help: "The version to install."),
                                 make(<positional-option>,
                                      name: "pkg",
                                      repeated?: #t,
                                      help: "Packages to install."))),
              make(<list-subcommand>,
                   options:
                     list(make(<flag-option>,
                               names: #("all", "a"),
                               help: "List all packages whether installed or not."))),
              make(<new-subcommand>,
                   options: list(make(<flag-option>,
                                      names: #("skip-workspace-check"),
                                      help: "Don't check whether already"
                                        " inside a workspace directory.",
                                      default: #f),
                                 make(<positional-option>,
                                      name: "name",
                                      help: "Workspace directory name."),
                                 make(<positional-option>,
                                      name: "pkg",
                                      repeated?: #t,
                                      help: "Active packages to be added"
                                        " to workspace file. The special name 'all'"
                                        " will install all known packages."))),
              make(<update-subcommand>,
                   options:
                     list(make(<flag-option>,
                               name: "pull",
                               help: "Pull the latest code for packages that are"
                                 " at version 'head'."))),
              make(<workspace-dir-subcommand>)))
end function;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <install-subcommand>)
 => (status :: false-or(<int>))
  for (package-name in get-option-value(subcmd, "pkg"))
    let vstring = get-option-value(subcmd, "version");
    let release = pm/find-package-release(pm/load-catalog(), package-name, vstring)
      | begin
          print("Package %= not found.", package-name);
          abort-command(1);
        end;
    pm/install(release);
  end;
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <list-subcommand>)
 => (status :: false-or(<int>))
  list-catalog(all?: get-option-value(subcmd, "all"))
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let pkg-names = get-option-value(subcmd, "pkg");
  let skip-workspace-check? = get-option-value(subcmd, "skip-workspace-check");
  ws/new(name, pkg-names, skip-workspace-check?: skip-workspace-check?);
  print("You may now run '%s update' in the new directory.", application-name());
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <update-subcommand>)
 => (status :: false-or(<int>))
  ws/configure(verbose?: get-option-value(parser, "verbose"),
               debug?: get-option-value(parser, "debug"));
  ws/update(update-head?: get-option-value(subcmd, "pull"));
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <workspace-dir-subcommand>)
 => (status :: false-or(<int>))
  // Needed for the Open Dylan Makefile.
  print("%s", as(<string>, locator-directory(ws/workspace-file())));
end method;


// List installed package names, synopsis, versions, etc. If `all` is
// true, show all packages. Installed and latest versions are shown.
define function list-catalog
    (#key all? :: <bool>)
  let cat = pm/load-catalog();
  for (pkg-name in sort(pm/package-names(cat)))
    let versions = pm/installed-versions(pkg-name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let package = pm/find-package(cat, pkg-name);
    let latest = pm/find-package-release(cat, pkg-name, pm/$latest);
    if (all? | latest-installed)
      print("%s (%s/%s) - %s",
            pkg-name,
            latest-installed | "-",
            pm/release-version(latest),
            pm/package-synopsis(package));
    end;
  end;
end function;

define function main () => (status :: false-or(<int>))
  let parser = make-command-line-parser();
  block (exit)
    parse-command-line(parser, application-arguments());
    if (get-option-value(parser, "verbose"))
      pm/set-verbose(#t);
    end;
    execute-command(parser);
  exception (err :: <abort-command-error>)
    print("%s", err);
    exit-status(err)
  end
end function;

exit-application(main() | 0);
