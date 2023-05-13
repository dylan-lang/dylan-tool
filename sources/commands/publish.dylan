Module: dylan-tool
Synopsis: The `dylan publish` command publishes a package to the catalog.


define class <publish-subcommand> (<subcommand>)
  keyword name = "publish";
  keyword help = "Publish a new package release to the catalog.";
end class;

define constant $publish-subcommand
  = make(<publish-subcommand>,
         options:
           list(make(<positional-option>,
                     names: #("catalog-directory"),
                     help: "Directory where you cloned pacman-catalog.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <publish-subcommand>)
 => (status :: false-or(<int>))
  let workspace = ws/load-workspace();
  let release = ws/workspace-release(workspace);
  let cat-dir = as(<directory-locator>,
                   get-option-value($publish-subcommand, "catalog-directory"));
  let cat = pm/catalog(directory: cat-dir);
  let name = pm/package-name(release);
  let latest = pm/find-package-release(cat, name, pm/$latest);
  if (release <= latest)
    // Have to use format-to-string here because error() uses simple-format
    // which doesn't call print-object methods.
    let message
      = format-to-string(
          "The latest published release of %= is %s. Increment the version"
          " in %s (and commit it) in order to publish a new version.",
          name, pm/release-version(release), ws/$dylan-package-file-name);
    error(message);
  end;
  if (yes-or-no?(format-to-string("About to publish %s, ok? ", release)))
    let file = pm/publish-release(cat, release);
    note("Package file written to %s. Commit the changes and submit a"
           " pull request.", file);
  else
    note("Aborted.");
  end;
end method;

define function yes-or-no? (prompt :: <string>) => (yes? :: <bool>)
  block (return)
    while (#t)
      format-out("\n%s", prompt);
      force-out();
      let answer = strip(read-line(*standard-input*));
      if (~member?(answer, #["yes", "no", "ok"], test: string-equal-ic?))
        format-out("Please enter yes or no.\n");
        force-out();
      else
        return(member?(answer, #["yes", "ok"], test: string-equal-ic?))
      end;
    end while;
  end
end function;
