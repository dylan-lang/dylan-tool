Module: %pacman

// This enables the #:string: prefix to "parse" raw string literals.
define function string-parser (s :: <string>) => (s :: <string>) s end;

// Name of the subdirectory in which packages are to be installed.
define constant $package-directory-name = "_packages";

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

define constant $dylan-env-var = "DYLAN";

define function dylan-directory
    () => (dir :: <directory-locator>)
  let basevar = select (os/$os-name)
                  #"win32" => "CSIDL_LOCAL_APPDATA";
                  otherwise => "XDG_STATE_HOME";
                end;
  let base = os/environment-variable(basevar);
  let home = os/environment-variable("HOME");
  let dylan = os/environment-variable($dylan-env-var);
  case
    dylan =>
      as(<directory-locator>, dylan);
    base =>
      subdirectory-locator(as(<directory-locator>, base), "dylan");
    home =>
      subdirectory-locator(as(<directory-locator>, home), ".local", "state", "dylan");
    otherwise =>
      package-error("Couldn't determine Dylan global package directory."
                      " Set the %s, %s, or HOME environment variable.",
                    $dylan-env-var, basevar);
  end
end function;

