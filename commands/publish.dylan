Module: dylan-tool-lib
Synopsis: The `dylan publish` command publishes a package to the catalog.


define class <publish-subcommand> (<subcommand>)
  keyword name = "publish";
  keyword help = "Publish a new package release to the catalog.";
end class;

define constant $publish-subcommand
  = make(<publish-subcommand>,
         options:
           list(make(<positional-option>,
                     names: #("package"),
                     variable: "PKG",
                     help: "Name of the package for which to publish a release.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <publish-subcommand>)
 => (status :: false-or(<int>))
  let workspace = ws/load-workspace();
  let name = get-option-value(subcmd, "package");
  let active-packages = ws/workspace-active-packages(workspace);
  let publish-release
    = find-element(active-packages,
                   method (rel)
                     string-equal-ic?(pm/package-name(rel), name)
                   end);
  let catalog-release
    = find-element(active-packages,
                   method (rel)
                     string-equal-ic?(pm/package-name(rel), "pacman-catalog")
                   end);
  if (~publish-release)
    format-out("Package %= is not an active package.\n", name);
    1
  elseif (~catalog-release)
    let ws-dir = ws/workspace-directory(ws/load-workspace());
    format-out(#:string:'
"pacman-catalog" is not an active package in this workspace.  For now, the way
packages are published is by making a pull request to the "pacman-catalog"
repository. This command will make the necessary changes for you, but you must
clone pacman-catalog first, using these commands:

  cd %s
  git clone https://github.com/dylan-lang/pacman-catalog
  cd pacman-catalog
  git checkout -t -b publish

Then re-run this command. Once the changes have been made, commit them and submit
a pull request. The GitHub continuous integration will verify the changes for you.
', ws-dir);
    1
  else
    // Looks good, let's publish...
    let release = pm/load-dylan-package-file(ws/active-package-file(workspace, name));
    os/environment-variable("DYLAN_CATALOG")
      := as(<byte-string>,
            ws/active-package-directory(workspace, pm/package-name(catalog-release)));
    let catalog = pm/catalog();
    pm/publish-release(catalog, release);
    0
  end
end method;
