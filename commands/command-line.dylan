Module: dylan-tool-commands
Synopsis: Definition of the command-line as a whole


// Parent of "new library" and "new workspace".
define class <new-subcommand> (<subcommand>)
  keyword name = "new";
  keyword help = "";
end;

define function dylan-tool-command-line
    () => (p :: <command-line-parser>)
  make(<command-line-parser>,
       help: format-to-string("Maintain Dylan dev workspaces and installed packages.\n"
                                "(Version: %s)\n",
                              $dylan-tool-version),
       options: list(make(<flag-option>,
                          name: "verbose",
                          help: "Generate more verbose output."),
                     make(<flag-option>,
                          name: "debug",
                          help: "Enter the debugger (or print a backtrace) on error.")),
       subcommands:
         list($install-subcommand,
              $list-subcommand,
              make(<new-subcommand>,
                   subcommands: list($new-library-subcommand,
                                     $new-workspace-subcommand)),
              $update-subcommand,
              $status-subcommand,
              $publish-subcommand))
end function;
