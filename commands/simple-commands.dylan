Module: dylan-tool-commands
Synopsis: Various command implementations not big enough to warrant their own file


/// dylan install

define class <install-subcommand> (<subcommand>)
  keyword name = "install";
  keyword help = "Install Dylan packages.";
end class;

define constant $install-subcommand
  = make(<install-subcommand>,
         options: list(make(<parameter-option>,
                            // TODO: type: <version>
                            names: #("version", "v"),
                            default: "latest",
                            help: "The version to install."),
                       make(<positional-option>,
                            name: "pkg",
                            repeated?: #t,
                            help: "Packages to install.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <install-subcommand>)
 => (status :: false-or(<int>))
  for (package-name in get-option-value(subcmd, "pkg"))
    let vstring = get-option-value(subcmd, "version");
    let release = pm/find-package-release(pm/catalog(), package-name, vstring)
      | begin
          log-info("Package %= not found.", package-name);
          abort-command(1);
        end;
    pm/install(release);
  end;
end method;


/// dylan list

define class <list-subcommand> (<subcommand>)
  keyword name = "list";
  keyword help = "List installed Dylan packages.";
end class;

define constant $list-subcommand
  = make(<list-subcommand>,
         options: list(make(<flag-option>,
                            names: #("all", "a"),
                            help: "List all packages whether installed"
                              " or not.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <list-subcommand>)
 => (status :: false-or(<int>))
  list-catalog(all?: get-option-value(subcmd, "all"))
end method;

// List installed package names, summary, versions, etc. If `all` is
// true, show all packages. Installed and latest versions are shown.
define function list-catalog
    (#key all? :: <bool>)
  let cat = pm/catalog();
  let packages = pm/load-all-catalog-packages(cat);
  local method package-< (p1, p2)
          p1.pm/package-name < p2.pm/package-name
        end;
  for (package in sort(packages, test: package-<))
    let name = pm/package-name(package);
    let versions = pm/installed-versions(name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let package = pm/find-package(cat, name);
    let latest = pm/find-package-release(cat, name, pm/$latest);
    if (all? | latest-installed)
      log-info("%s (Installed: %s, Latest: %s) - %s",
               name,
               latest-installed | "-",
               pm/release-version(latest),
               pm/package-description(package));
    end;
  end;
end function;


/// dylan new workspace

define class <new-workspace-subcommand> (<subcommand>)
  keyword name = "workspace";
  keyword help = "Create a new workspace.";
end class;

define constant $new-workspace-subcommand
  = make(<new-workspace-subcommand>,
         options: list(make(<parameter-option>,
                            names: #("directory", "d"),
                            help: "Create the workspace in this directory."),
                       make(<positional-option>,
                            name: "name",
                            help: "Workspace directory name.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-workspace-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dir = get-option-value(subcmd, "directory");
  ws/new(name, parent-directory: dir & as(<directory-locator>, dir));
  0
end method;


/// dylan update

define class <update-subcommand> (<subcommand>)
  keyword name = "update";
  keyword help = "Bring the current workspace up-to-date with the workspace.json file.";
end class;

define constant $update-subcommand
  = make(<update-subcommand>);

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <update-subcommand>)
 => (status :: false-or(<int>))
  ws/update();
end method;


/// dylan status

define class <status-subcommand> (<subcommand>)
  keyword name = "status";
  keyword help = "Display information about the current workspace.";
end class;

define constant $status-subcommand
  = make(<status-subcommand>,
         options: list(make(<flag-option>, // for tooling
                            name: "directory",
                            help: "Only show the workspace directory.")));

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