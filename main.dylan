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

// Create the #str:"..." syntax.
define function str-parser (s :: <string>) => (s :: <string>) s end;

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
define function make-command-line-parser () => (p :: <command-line-parser>)
  make(<command-line-parser>,
       // global options available to all commands
       options: list(make(<flag-option>, names: #("verbose")),
                     make(<flag-option>, names: #("debug"))),
       subcommands:
         vector(make(<subcommand>,
                     name: "install",
                     min-positional-arguments: 1,
                     options: list(make(<parameter-option>,
                                        // TODO: type: <version>
                                        names: #("version", "v"))),
                     help: #:str:"%app install [options] <pkg> ...
    Install a package into ${DYLAN}/pkg. <version> may be a version
    number of the form 1.2.3, 'latest' to install the latest numbered
    version, or 'head'."),
                make(<subcommand>,
                     name: "list",
                     max-positional-arguments: 0,
                     options: list(make(<flag-option>,
                                        names: #("all", "a"))),
                     help: #:str:"%app list [--all]
    List installed packages. With --all, list all packages in the
    catalog along with the latest available version. (grep is your
    friend here.)"),
                make(<subcommand>,
                     name: "new",
                     min-positional-arguments: 2,
                     help: #:str:"%app new <workspace> <pkg>...
    Create a new workspace with the specified active packages. If the
    single package 'all' is specified the workspace will contain all
    packages found in the package catalog."),
                make(<subcommand>,
                     name: "update",
                     max-positional-arguments: 0,
                     options: list(make(<flag-option>,
                                        names: #("update-head"))),
                     help: #:str:{%app update [--update-head]
    Bring the current workspace up-to-date with the workspace.json file.
    Install dependencies and update the registry for any new .lid files.
    If --update-head is provided, the latest changes are fetched for
    packages that are installed at version "head".}),
                make(<subcommand>,
                     name: "workspace-dir",
                     min-positional-arguments: 1,
                     max-positional-arguments: 1,
                     help: #:str:"%app workspace-dir
    Print the pathname of the workspace directory.")))
end function;

define function main () => (status :: <int>)
  let parser = make-command-line-parser();
  block (exit)
    parse-command-line(parser, application-arguments());
    let debug? = get-option-value(parser, "debug");
    let verbose? = get-option-value(parser, "verbose");
    let subcommand = parser-subcommand(parser);
    select (subcommand.command-name by \=)
    ws/configure(verbose?: verbose?, debug?: debug?);
    select (subcmd by istr=)
      "install" =>
        for (package-name in subcmd.positional-arguments)
          let vstring = get-option-value(subcmd, "version") | "latest";
          let release = pm/find-package-release(pm/load-catalog(), package-name, vstring)
            | error("package %= not found", package-name);
          pm/install(release);
        end;
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
      "workspace-dir" =>
        // Needed for the Open Dylan Makefile.
        print("%s", as(<string>, locator-directory(ws/workspace-file())));
      otherwise =>
        print("%= not recognized", subcmd);
        usage();
    end select;
    0
  exception (err :: <error>, test: method (_) ~debug? end)
    print("Error: %s", err);
    1
  end
end function;

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

exit-application(main());
