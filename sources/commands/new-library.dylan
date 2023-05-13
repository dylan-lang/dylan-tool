Module: dylan-tool
Synopsis: Create the initial boilerplate for new Dylan libraries and applications


define class <new-application-subcommand> (<new-subcommand>)
  keyword name = "application";
  keyword help = "Create a new application and its test library.";
end class;

define class <new-library-subcommand> (<new-subcommand>)
  keyword name = "library";
  keyword help = "Create a new shared library and its test library.";
end class;

define constant $deps-option
  = make(<positional-option>,
         names: #("deps"),
         required?: #f,
         repeated?: #t,
         help: "Package dependencies in the form pkg@version."
           " 'pkg' with no version gets the current latest"
           " version. pkg@1.2 means a specific version. The test"
           " suite executable automatically depends on testworks.");

// dylan new application foo http json ...
define constant $new-application-subcommand
  = make(<new-application-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("force-package", "p"),
                     help: "Create dylan-package.json even if"
                       " already in a package",
                     default: #f),
                make(<positional-option>,
                     names: #("name"),
                     help: "Name of the application"),
                make(<flag-option>,
                     names: #("simple"),
                     help: "Create only an executable library, without"
                       " a corresponding shared library or test suite.",
                     default: #f),
                $deps-option));

// dylan new library foo http json ...
define constant $new-library-subcommand
  = make(<new-library-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("force-package", "p"),
                     help: "Create dylan-package.json even if"
                       " already in a package",
                     default: #f),
                make(<positional-option>,
                     names: #("name"),
                     help: "Name of the library"),
                $deps-option));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-application-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dep-specs = get-option-value(subcmd, "deps") | #[];
  let force-package? = get-option-value(subcmd, "force-package");
  new-library(name,
              dependencies: dep-specs,
              executable?: #t,
              force-package?: force-package?,
              simple?: get-option-value(subcmd, "simple"));
  0
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-library-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dep-specs = get-option-value(subcmd, "deps") | #[];
  let force-package? = get-option-value(subcmd, "force-package");
  new-library(name,
              dependencies: dep-specs,
              executable?: #f,
              force-package?: force-package?);
  0
end method;

// While technically any Dylan name is valid, we prefer to restrict the names
// to the style that is in common use since this tool is most likely to be used
// by beginners.
define constant $library-name-regex = compile-regex("^[a-z][a-z0-9-]*$");

define function new-library
    (name :: <string>,
     #key directory :: <directory-locator> = fs/working-directory(),
          dependencies :: <seq> = #[], executable? :: <bool>,
          force-package? :: <bool>, simple? :: <bool>)
  if (~regex-search($library-name-regex, name))
    error("%= is not a valid Dylan library name."
            " Names are one or more words separated by hyphens, for example"
            " 'cool-stuff'. Names must match the regular expression %=.",
          name, regex-pattern($library-name-regex));
  end;
  let lib-dir = subdirectory-locator(directory, name);
  if (fs/file-exists?(lib-dir))
    error("Directory %s already exists.", lib-dir);
  end;
  // Parse dep specs before writing any files, in case of errors.
  let deps = parse-dep-specs(dependencies);
  make-dylan-library(name, lib-dir, executable?,
                     deps, force-package?, simple?);
end function;

// Creates source files for a new library (app or shared lib), its
// corresponding test library app, and a dylan-package.json file.

// Define #:string: syntax.
define function string-parser (s) s end;


//// Templates for a "simple" executable app with no shared library or test
//// suite. For this one we don't add "-app" to the name of the library. The
//// idea is that this is for quick, one-off apps like benchmarks and such.

define constant $simple-exe-lid-template
  = #:string:"Library: %s
Files: library.dylan
       %s.dylan
Target-Type: executable
";

// library.dylan file for an simple executable library.
define constant $simple-exe-library-definition-template
  = #:string:"Module: dylan-user
Synopsis: Module and library definition for simple executable application

define library %s
  use common-dylan;
  use io, import: { format-out };
end library;

define module %s
  use common-dylan;
  use format-out;
end module;
";

define constant $simple-exe-main-template
  = #:string:'Module: %s

define function main
    (name :: <string>, arguments :: <vector>)
  format-out("Hello, world!\n");
  exit-application(0);
end function;

// Calling our top-level function (which may have any name) is the last
// thing we do.
main(application-name(), application-arguments());
';


//// Shared library templates.

define constant $lib-lid-template
  = #:string:"Library: %s
Files: library.dylan
       %s.dylan
Target-Type: dll
";

define constant $lib-library-definition-template
  = #:string:'Module: dylan-user

define library %s
  use common-dylan;
  use io, import: { format-out };

  export
    %s,
    %s-impl;
end library;

// Interface module creates public API, ensuring that an implementation
//  module exports them.
define module %s
  create
    greeting;                   // Example. Delete me.
end module;

// Implementation module implements definitions for names created by the
// interface module and exports names for use by test suite.  %%foo, foo-impl,
// or foo-internal are common names for an implementation module.
define module %s-impl
  use common-dylan;
  use %s;                  // Declare that we will implement "greeting".

  // Additional exports for use by test suite.
  export
    $greeting;                  // Example code. Delete me.
end module;
';

define constant $lib-main-code-template
  = #:string:'Module: %s-impl

// Internal
define constant $greeting = "Hello world!";

// Exported
define function greeting () => (s :: <string>)
  $greeting
end function;
';


//// Templates for a full executable library that is designed to use the base
//// shared library.

define constant $exe-lid-template
  = #:string:"Library: %s-app
Files: %s-app-library.dylan
       %s-app.dylan
Target-Type: executable
";

// library.dylan file for an non-simple executable library.
define constant $exe-library-definition-template
  = #:string:"Module: dylan-user
Synopsis: Module and library definition for executable application

define library %s-app
  use common-dylan;
  use %s;
  use io, import: { format-out };
end library;

define module %s-app
  use common-dylan;
  use format-out;
  use %s;
end module;
";

// Main program for the executable.
define constant $exe-main-template
  = #:string:'Module: %s-app

define function main
    (name :: <string>, arguments :: <vector>)
  format-out("%%s\n", greeting());
  exit-application(0);
end function;

// Calling our main function (which could have any name) should be the last
// thing we do.
main(application-name(), application-arguments());
';


//// Templates for test suite library.

define constant $test-lid-template
  = #:string:"Library: %s-test-suite
Files: library.dylan
       %s-test-suite.dylan
Target-Type: executable
";

define constant $test-library-definition-template
  = #:string:'Module: dylan-user

define library %s-test-suite
  use common-dylan;
  use testworks;
  use %s;
end library;

define module %s-test-suite
  use common-dylan;
  use testworks;
  use %s;
  use %s-impl;
end module;
';

define constant $test-main-code-template
  = #:string:'Module: %s-test-suite

define test test-$greeting ()
  assert-equal("Hello world!", $greeting);
end test;

define test test-greeting ()
  assert-equal("Hello world!", greeting());
end test;

// Use `_build/bin/%s-test-suite --help` to see options.
run-test-application()
';

// TODO: We don't have enough info to fill in "location" here. Since this will
// be an active package, location shouldn't be needed until the package is
// published in the catalog, at which time the user should be gently informed.
define constant $dylan-package-file-template
  = #:string:'{
    "dependencies": [ %s ],
    "dev-dependencies": [ "testworks" ],
    "description": "YOUR DESCRIPTION HERE",
    "name": %=,
    "version": "0.1.0",
    "url": "https://github.com/YOUR-ORG-HERE/YOUR-REPO-HERE"
}
';

define class <template> (<object>)
  constant slot format-string :: <string>, required-init-keyword: format-string:;
  constant slot format-arguments :: <seq> = #(), init-keyword: format-arguments:;
  constant slot output-file :: <file-locator>, required-init-keyword: output-file:;
  constant slot library-name :: false-or(<string>) = #f, init-keyword: library-name:;
end class;

define function write-template
    (template :: <template>) => ()
  fs/ensure-directories-exist(template.output-file);
  fs/with-open-file (stream = template.output-file,
                     direction: #"output",
                     if-does-not-exist: #"create",
                     if-exists: #"error")
    apply(format, stream, template.format-string, template.format-arguments);
  end;
end function;

// Write files for various libraries based on the args.
define function make-dylan-library
    (name :: <string>, dir :: <directory-locator>, exe? :: <bool>, deps :: <seq>,
     force-package? :: <bool>, simple? :: <bool>)
  local
    method file (name)
      merge-locators(as(<file-locator>, name), dir)
    end,
    method test-file (name)
      merge-locators(as(<file-locator>, name),
                     subdirectory-locator(dir, "tests"))
    end,
    method dep-string (dep)
      format-to-string("%=", pm/dep-to-string(dep))
    end;
  let test-name = concat(name, "-test-suite");
  let deps-string = join(map-as(<vector>, dep-string, deps), ", ");
  let base-library-templates
    = list(make(<template>,
                library-name: name,
                output-file: file(concat(name, ".lid")),
                format-string: $lib-lid-template,
                format-arguments: list(name, name)),
           make(<template>,
                output-file: file("library.dylan"),
                format-string: $lib-library-definition-template,
                format-arguments: list(name, name, name, name, name, name)),
           make(<template>,
                output-file: file(concat(name, ".dylan")),
                format-string: $lib-main-code-template,
                format-arguments: list(name)),
           // Test library files...
           make(<template>,
                library-name: test-name,
                output-file: test-file(concat(test-name, ".lid")),
                format-string: $test-lid-template,
                format-arguments: list(name, name)),
           make(<template>,
                output-file: test-file("library.dylan"),
                format-string: $test-library-definition-template,
                format-arguments: list(name, name, name, name, name)),
           make(<template>,
                output-file: test-file(concat(test-name, ".dylan")),
                format-string: $test-main-code-template,
                format-arguments: list(name, name)));
  let app-templates
    = list(make(<template>,
                library-name: concat(name, "-app"),
                output-file: file(concat(name, "-app.lid")),
                format-string: $exe-lid-template,
                format-arguments: list(name, name, name)),
           make(<template>,
                output-file: file(concat(name, "-app-library.dylan")),
                format-string: $exe-library-definition-template,
                format-arguments: list(name, name, name, name)),
           make(<template>,
                output-file: file(concat(name, "-app.dylan")),
                format-string: $exe-main-template,
                format-arguments: list(name)));
  let simple-app-templates
    = list(make(<template>,
                library-name: name,
                output-file: file(concat(name, ".lid")),
                format-string: $simple-exe-lid-template,
                format-arguments: list(name, name)),
           make(<template>,
                output-file: file("library.dylan"),
                format-string: $simple-exe-library-definition-template,
                format-arguments: list(name, name)),
           make(<template>,
                output-file: file(concat(name, ".dylan")),
                format-string: $simple-exe-main-template,
                format-arguments: list(name)));
  let templates
    = if (simple?)
        simple-app-templates    // no test suite, no shared library
      elseif (exe?)
        concat(base-library-templates, app-templates)
      else
        base-library-templates
      end;
  let pkg-file = ws/find-dylan-package-file(dir);
  let old-pkg-file = pkg-file & simplify-locator(pkg-file);
  let new-pkg-file = simplify-locator(file(ws/$dylan-package-file-name));
  if (old-pkg-file & ~force-package?)
    warn("Package file %s exists. Skipping creation.", old-pkg-file);
  else
    if (old-pkg-file)
      warn("This package is being created inside an existing package.");
    end;
    verbose("Edit %s if you need to change dependencies or if you plan"
              " to publish this library as a package.",
            new-pkg-file);
    templates
      := add(templates,
             make(<template>,
                  output-file: new-pkg-file,
                  format-string: $dylan-package-file-template,
                  format-arguments: list(deps-string, name)));
  end;
  for (template in templates)
    write-template(template);
    let name = template.library-name;
    if (name)
      note("Created library %s.", name)
    end;
  end;
  ws/update(directory: dir);
end function;

// Parse dependency specs like lib, lib@latest, or lib@1.2. Deps are always
// resolved to a specific released semantic version.
define function parse-dep-specs
    (specs :: <seq>) => (deps :: pm/<dep-vector>)
  let cat = pm/catalog();
  map-as(pm/<dep-vector>,
         method (spec)
           let dep = pm/string-to-dep(spec);
           let ver = pm/dep-version(dep);
           let rel = pm/find-package-release(cat, pm/package-name(dep), ver)
             | error("No released version found for dependency %=.", spec);
           if (ver = pm/$latest)
             make(pm/<dep>,
                  package-name: pm/package-name(dep),
                  version: pm/release-version(rel))
           else
             dep
           end
         end,
         specs)
end function;
