Module: %pacman

// This enables the #string: prefix to "parse" raw string literals.
define function string-parser (s :: <string>) => (s :: <string>) s end;

// Name of the directory under $DYLAN where installed versions are stored.
define constant $package-directory-name = "pkg";

// Exported
// The package manager will never modify anything outside this directory unless
// explicitly requested (e.g., via a directory passed to download).
define function package-manager-directory
    () => (dir :: <directory-locator>)
  subdirectory-locator(dylan-directory(), $package-directory-name)
end function;

define variable *verbose-output?* = #f;

define function set-verbose (verbose? :: <bool>)
  *verbose-output?* := verbose?
end;

define function message
    (pattern :: <string>, #rest args) => ()
  apply(printf, pattern, args)
end;

define function verbose-message
    (pattern :: <string>, #rest args) => ()
  *verbose-output?* & apply(printf, pattern, args);
end;

ignorable(message, verbose-message);

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
  let dylan = os/getenv($dylan-env-var);
  if (dylan)
    as(<directory-locator>, dylan)
  else
    // TODO: use %APPDATA% on Windows
    let home = os/getenv("HOME");
    if (home)
      subdirectory-locator(as(<directory-locator>, home), $dylan-dir-name)
    else
      as(<directory-locator>, $default-dylan-directory)
    end
  end
end function;

