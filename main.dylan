Module: dylan-tool

// I'm undecided whether to go forward with this tool in the long run
// or to try and use Deft, but I don't want to deal with Deft's
// problems right now so this should be a pretty simple way to get
// workspaces and packages working.

// TODO:
// * The 'list' subcommand is showing a random set of packages in my ws.all
//   workspace.

define function print (format-string, #rest args)
  apply(format, *stdout*, format-string, args);
  write(*stdout*, "\n");
  // OD doesn't currently have an option for flushing output after \n.
  flush(*stdout*);
end;

// Create the #str:"..." syntax.
define function str-parser (s :: <string>) => (s :: <string>) s end;

define function main () => (status :: <int>)
  let debug? = #f;
  block (exit)
    // TODO: command parsing is ad-hoc because command-line-parser
    //       doesn't do well with subcommands. Needs improvement.
    let app = locator-name(as(<file-locator>, application-name()));
    local method usage (#key status :: <int> = 2)
            print(#:str:`Usage:
%s install <pkg> <version>
    Install a package into ${DYLAN}/pkg. <version> may be a version
    number of the form 1.2.3, 'latest' to install the latest numbered
    version, or 'head'.

%s list [--all]
    List installed packages. With --all, list all packages in the
    catalog along with the latest available version. (grep is your
    friend here.)

%s new <workspace> <pkg>...
    Create a new workspace with the specified active packages. If the
    single package 'all' is specified the workspace will contain all
    packages found in the package catalog.

%s update [--update-head]
    Bring the current workspace up-to-date with the workspace.json file.
    Install dependencies and update the registry for any new .lid files.
    If --update-head is provided, the latest changes are fetched for
    packages that are installed at version "head".

Notes:
  A --verbose flag may be added (anywhere) to see more detailed output.
`, app, app, app, app, app, app);
            exit(status);
          end;
    let args = application-arguments();
    if (args.size = 0
          | member?("--help", args, test: istr=)
          | member?("-h", args, test: istr=))
      usage(status: 0);
    end;
    let subcmd = args[0];
    let args = slice(args, 1, #f);
    if (member?("--debug", args, test: istr=))
      args := remove(args, "--debug", test: istr=);
      debug? := #t;
    end;
    let verbose? = #f;
    if (member?("--verbose", args, test: istr=))
      args := remove(args, "--verbose", test: istr=);
      verbose? := #t;
    end;
    ws/configure(verbose?: verbose?, debug?: debug?);
    select (subcmd by istr=)
      "install" =>
        // Install a specific package.
        args.size = 2 | usage();
        let pkg-name = args[0];
        let vstring = args[1];
        let pkg = pm/find-package(pm/load-catalog(), pkg-name, vstring);
        if (~pkg)
          error("Package %s not found.", pkg-name);
        end;
        pm/install(pkg);
      "list" =>
        list-catalog(all?: member?("--all", args, test: istr=));
      "new" =>                  // Create a new workspace.
        args.size >= 2 | usage();
        let name = args[0];
        let pkg-names = slice(args, 1, #f);
        ws/new(name, pkg-names);
        print("You may now run '%s update' in the new directory.", app);
      "update" =>
        if (args.size > 1 | (args.size = 1 & args[0] ~= "--update-head"))
          usage();
        end;
        let update-head? = args.size = 1 & args[0] = "--update-head";
        ws/update(update-head?: update-head?); // Update the workspace based on config file.
      otherwise =>
        print("%= not recognized", subcmd);
        usage();
    end select;
    0
  exception (err :: <error>, test: method (_) ~debug? end)
    print("Error: %s", err);
    1
  end
end function main;

// List installed package names, synopsis, versions, etc. If `all` is
// true, show all packages. Installed and latest versions are shown.
define function list-catalog (#key all? :: <bool>)
  let cat = pm/load-catalog();
  for (pkg-name in sort(pm/package-names(cat)))
    let versions = pm/installed-versions(pkg-name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let entry = pm/find-entry(cat, pkg-name);
    let latest = pm/find-package(cat, pkg-name, pm/$latest);
    if (all? | latest-installed)
      print("%s (%s/%s) - %s",
            pkg-name,
            latest-installed | "-",
            pm/version(latest),
            pm/synopsis(entry));
    end;
  end;
end;

exit-application(main());
