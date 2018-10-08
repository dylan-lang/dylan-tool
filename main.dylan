Module: dylan-tool
Synopsis: The "dylan" command: "dylan install", "dylan build", "dylan doc", etc.

// I'm undecided whether to go forward with this tool in the long run
// or to try and use Deft, but I don't want to deal with Deft's
// problems right now so this should be a pretty simple way to get
// workspaces and packages working.

define function main () => ()
  let parser = make-command-line-parser();
  let args = application-arguments();
  if (args.size ~= 2)
    usage();
  elseif (args[0] ~= "install")
    usage();
  else
    block ()
      let pkg-name = args[1];
      let pkg = pkg/find-package(pkg-name, pkg/$latest);
      pkg/install-package(pkg);
    exception (err :: pkg/<package-error>)
      format-err("%s", err);
    end;
  end if; 
end;

define function usage() => ()
  format-err("Usage: %s install <pkg>\n", application-name());
  format-err("(Only the 'install' command is supported for now.)\n");
end;

define function make-command-line-parser
    () => (parser :: cli/<parser>)
  let parser = make(cli/<parser>,
                    min-positional-options: 2,
                    max-positional-options: 2);
  parser
end;

main();
