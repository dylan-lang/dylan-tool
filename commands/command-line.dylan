Module: dylan-tool-commands
Synopsis: Definition of the command-line as a whole


define function dylan-tool-command-line
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
                     // TODO: new package
                     list(make(<new-library-subcommand>,
                               // dylan new library --exe foo <dep> ...
                               options:
                                 list(make(<flag-option>,
                                           names: #("executable", "x"),
                                           help: "The library creates an executable binary"),
                                      make(<positional-option>,
                                           names: #("name"),
                                           help: "Name of the library"),
                                      // TODO: dev-dependencies
                                      make(<positional-option>,
                                           names: #("deps"),
                                           required?: #f,
                                           repeated?: #t,
                                           help: "Package dependencies in the form pkg@version."
                                             " 'pkg' with no version gets the current latest"
                                             " version. pkg@1.2 means a specific version. The test"
                                             " library automatically depends on testworks."))),
                          make(<new-workspace-subcommand>,
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
