Module: dylan-tool

// TODO:
// * The 'list' subcommand is showing a random set of packages in my "all"
//   workspace.

define class <install-subcommand> (<subcommand>)
  keyword name = "install";
  keyword help = "Install Dylan packages.";
end class;

define class <new-subcommand> (<subcommand>)
  keyword name = "new";
  keyword help = "";
end;

define class <workspace-subcommand> (<subcommand>)
  keyword name = "workspace";
  keyword help = "Create a new workspace.";
end class;

define class <update-subcommand> (<subcommand>)
  keyword name = "update";
  keyword help = "Bring the current workspace up-to-date with the workspace.json file.";
end class;

define class <list-subcommand> (<subcommand>)
  keyword name = "list";
  keyword help = "List installed Dylan packages.";
end class;

define class <status-subcommand> (<subcommand>)
  keyword name = "status";
  keyword help = "Display information about the current workspace.";
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
                   options: list(make(<flag-option>,
                                      names: #("all", "a"),
                                      help: "List all packages whether installed"
                                        " or not."))),
              make(<new-subcommand>,
                   subcommands:
                     // TODO: new package, new library
                     list(make(<workspace-subcommand>,
                               options: list(make(<parameter-option>,
                                                  names: #("directory", "d"),
                                                  help: "Create the workspace in this directory."),
                                             make(<positional-option>,
                                                  name: "name",
                                                  help: "Workspace directory name."))))),
              make(<update-subcommand>),
              make(<status-subcommand>,
                   options: list(make(<flag-option>, // for tooling
                                      name: "directory",
                                      help: "Only show the workspace directory.")))))
end function;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <install-subcommand>)
 => (status :: false-or(<int>))
  for (package-name in get-option-value(subcmd, "pkg"))
    let vstring = get-option-value(subcmd, "version");
    let release = pm/find-package-release(pm/load-catalog(), package-name, vstring)
      | begin
          log-info("Package %= not found.", package-name);
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
    (parser :: <command-line-parser>, subcmd :: <workspace-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dir = get-option-value(subcmd, "directory");
  ws/new(name, parent-directory: dir & as(<directory-locator>, dir));
  0
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <update-subcommand>)
 => (status :: false-or(<int>))
  ws/update();
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <status-subcommand>)
 => (status :: false-or(<int>))
  let workspace = ws/load-workspace(fs/working-directory());
  if (~workspace)
    log-info("Not currently in a workspace.");
    abort-command(1);
  end;
  log-info("Workspace: %s", ws/workspace-directory(workspace));
  if (get-option-value(subcmd, "directory"))
    abort-command(0);
  end;

  // Show active package status
  // TODO: show current branch name and whether modified and whether ahead of
  //   upstream (usually but not always origin/master).
  let active = ws/workspace-active-packages(workspace);
  if (empty?(active))
    log-info("No active packages.");
  else
    log-info("Active packages:");
    for (package in active)
      let directory = ws/active-package-directory(workspace, pm/package-name(package));
      let command = "git status --untracked-files=no --branch --ahead-behind --short";
      let (status, output) = run(command, working-directory: directory);
      let line = split(output, "\n")[0];

      let command = "git status --porcelain --untracked-files=no";
      let (status, output) = run(command, working-directory: directory);
      let dirty = ~whitespace?(output);

      log-info("  %-25s: %s%s", pm/package-name(package), line, (dirty & " (dirty)") | "");
    end;
  end;

  0
end method;

// Run an executable or shell command. `command` may be a string or a sequence
// of strings. If a string it is run with `/bin/sh -c`. If a sequence of
// strings the first element is the executable pathname. Returns the exit
// status of the command and the combined output to stdout and stderr.
define function run
    (command :: <seq>, #key working-directory :: false-or(<directory-locator>))
 => (status :: <int>, output :: <string>)
  let stream = make(<string-stream>, direction: #"output");
  let status = os/run(command,
                      under-shell?: instance?(command, <string>),
                      working-directory: working-directory,
                      outputter: method (string, #rest ignore)
                                   write(stream, string)
                                 end);
  values(status, stream.stream-contents)
end function;

// List installed package names, summary, versions, etc. If `all` is
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
      log-info("%s (%s/%s) - %s",
               pkg-name,
               latest-installed | "-",
               pm/release-version(latest),
               pm/package-summary(package));
    end;
  end;
end function;

define function main () => (status :: false-or(<int>))
  // Configure logging. We use the logging module for output so we can control verbosity
  // that way.
  log-formatter(*log*) := make(<log-formatter>, pattern: "%s  %m");

  let parser = make-command-line-parser();
  block (exit)
    parse-command-line(parser, application-arguments());
    if (get-option-value(parser, "verbose"))
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

exit-application(main() | 0);
