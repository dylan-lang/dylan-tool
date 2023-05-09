Module: %pacman

// This enables the #:string: prefix to "parse" raw string literals.
define function string-parser (s :: <string>) => (s :: <string>) s end;

// Name of the subdirectory in which packages are to be installed.
define constant $package-directory-name = "pkg";

// This provides a way for dylan-tool commands to override the default package
// installation directory without threading it through the entire call chain,
// so that (for example) package installations can be local to a workspace
// rather than global. (In the long run, do we even want global installations?)
define thread variable *package-manager-directory* :: false-or(<directory-locator>) = #f;

// The package manager will never modify anything outside this directory unless
// explicitly requested (e.g., via a directory passed to download).
define function package-manager-directory
    () => (dir :: <directory-locator>)
  *package-manager-directory*
    | subdirectory-locator(dylan-directory(), $package-directory-name)
end function;

// TODO: Windows
define constant $default-dylan-directory = "/opt/dylan";
define constant $dylan-dir-name = "dylan";
define constant $dylan-env-var = "DYLAN";

// The base directory for all things Dylan for a given user.
//   1. ${DYLAN}
//   2. ${HOME}/dylan or %APPDATA%\dylan
//   3. /opt/dylan or ??? on Windows
// TODO: Dylan implementations should export this.
define function dylan-directory
    () => (dir :: <directory-locator>)
  let dylan = os/environment-variable($dylan-env-var);
  if (dylan)
    as(<directory-locator>, dylan)
  else
    // TODO: use %APPDATA% on Windows
    let home = os/environment-variable("HOME");
    if (home)
      subdirectory-locator(as(<directory-locator>, home), $dylan-dir-name)
    else
      as(<directory-locator>, $default-dylan-directory)
    end
  end
end function;

