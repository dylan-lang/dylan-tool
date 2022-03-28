Module: dylan-tool
Synopsis: The `dylan new library` subcommand

// Creates source files for a new library (app or shared lib), its
// corresponding test library app, and a pkg.json file.

// Define #:string: syntax.
define function string-parser (s) s end;

// LID file for both exe and lib.
define constant $lid-template
  = #:string:"Library: %s
Files: library.dylan
       %s.dylan
";

// library.dylan file for an executable library.
define constant $exe-library-template
  = #:string:"Module: dylan-user

define library %s
  use common-dylan;
  use io, import: { format-out };

  // Export module for use by test suite.
  export
    %s;
end library;

define module %s
  use common-dylan;
  use format-out;

  // Exports for use by test suite.
  export
    $greeting;
end module;
";

// Main program for an executable application.
define constant $exe-main-template
  = #:string:'Module: %s

define constant $greeting = "Hello world!";

define function main
    (name :: <string>, arguments :: <vector>)
  format-out("%%s\n", $greeting);
end function;

main(application-name(), application-arguments())
';

// library.dylan for a test library for an application.
define constant $exe-test-library-template
  = #:string:"Module: dylan-user

define library %s-test-suite
  use common-dylan;
  use testworks;
  use %s;
end library;

define module %s-test-suite
  use common-dylan;
  use testworks;
  use %s;
end module;
";

define constant $exe-test-main-template
  = #:string:'Module: %s-test-suite

define test test-greeting ()
  assert-equal("Hello world!", $greeting);
end test;

// Run `_build/bin/%s-test-suite --help` to see options.
run-test-application()
';

define constant $lib-library-template
  = #:string:'Module: dylan-user

define library %s
  use common-dylan;
  use io, import: { format-out };

  export
    %s,
    %s-impl;
end library;

// Interface module exports public API.
define module %s
  create
    greeting;
end module;

// Implementation module implements definitions for names created by the
// interface module and exports names for use by test suite.  %%foo, foo-impl,
// or foo-internal are common names for an implementation module.
define module %s-impl
  use common-dylan;
  use %s;                  // Declare that we will implement "greeting".

  // Additional exports for use by test suite.
  export
    $greeting;
end module;
';

define constant $lib-main-template
  = #:string:'Module: %s-impl

// Internal
define constant $greeting = "Hello world!";

// Exported
define function greeting () => (s :: <string>)
  $greeting
end function;
';

define constant $lib-test-library-template
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

define constant $lib-test-main-template
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
define constant $pkg-template
  = #:string:'{
    "dependencies": [ %s ],
    "description": "** put description here **",
    "name": %=,
    "version": "0.1.0",
    "url": "** put repo url here **"
}
';

define class <template> (<object>)
  constant slot format-string :: <string>, required-init-keyword: format-string:;
  constant slot format-arguments :: <seq> = #(), init-keyword: format-arguments:;
  constant slot output-file :: <file-locator>, required-init-keyword: output-file:;
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

// Write files for a library named `name` in directory `dir`.
define function make-dylan-library
    (name :: <string>, dir :: <directory-locator>, exe? :: <bool>, deps :: <seq>) => ()
  local method file (name)
          merge-locators(as(<file-locator>, name), dir)
        end;
  local method test-file (name)
          merge-locators(as(<file-locator>, name),
                         subdirectory-locator(dir, "tests"))
        end;
  let test-name = concat(name, "-test-suite");
  let deps-string = join(map-as(<vector>,
                                method (dep)
                                  format-to-string("%=", pm/dep-to-string(dep))
                                end,
                                deps),
                         ", ");
  let templates
    = list(// Main library files...
           make(<template>,
                output-file: file(concat(name, ".lid")),
                format-string: $lid-template,
                format-arguments: list(name, name)),
           make(<template>,
                output-file: file("library.dylan"),
                format-string: iff(exe?,
                                   $exe-library-template,
                                   $lib-library-template),
                format-arguments: iff(exe?,
                                      list(name, name, name),
                                      list(name, name, name, name, name, name))),
           make(<template>,
                output-file: file(concat(name, ".dylan")),
                format-string: iff(exe?, $exe-main-template, $lib-main-template),
                format-arguments: list(name)),
           // Test library files...
           make(<template>,
                output-file: test-file(concat(test-name, ".lid")),
                format-string: $lid-template,
                format-arguments: list(test-name, test-name)),
           make(<template>,
                output-file: test-file("library.dylan"),
                format-string: iff(exe?,
                                   $exe-test-library-template,
                                   $lib-test-library-template),
                format-arguments: iff(exe?,
                                      list(name, name, name, name),
                                      list(name, name, name, name, name))),
           make(<template>,
                output-file: test-file(concat(test-name, ".dylan")),
                format-string: iff(exe?,
                                   $exe-test-main-template,
                                   $lib-test-main-template),
                format-arguments: list(name, name)),
           make(<template>,
                output-file: file("pkg.json"),
                format-string: $pkg-template,
                format-arguments: list(deps-string, name))); 
  for (template in templates)
    write-template(template)
  end;
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

// While technically any Dylan name is valid, we prefer to restrict the names
// to the style that is in common use since this tool is most likely to be used
// by beginners.
define constant $library-name-regex = re/compile("^[a-z][a-z0-9-]*$");

// TODO: We currently always create a pkg.json file. Detect whether the new
// library is inside an existing package, at workspace top-level, or what,
// since it's valid to create a new library inside an existing package.
define function new-library
    (name :: <string>, dir :: <directory-locator>, dep-specs :: <seq>, exe? :: <bool>)
  if (~re/search($library-name-regex, name))
    error("%= is not a valid Dylan library name."
            " Names are one or more words separated by hyphens, for example"
            "'cool-stuff'. Names must match the regular expression %=.",
          name, re/pattern($library-name-regex));
  end;
  let lib-dir = subdirectory-locator(dir, name);
  if (fs/file-exists?(lib-dir))
    error("Directory %s already exists.", lib-dir);
  end;
  // Parse dep specs before writing any files, in case of errors.
  let deps = parse-dep-specs(dep-specs);
  if (~any?(method (dep)
              "testworks" = lowercase(pm/package-name(dep))
            end,
            deps))
    deps := concatenate-as(pm/<dep-vector>, deps, parse-dep-specs(list("testworks")));
  end;
  make-dylan-library(name, lib-dir, exe?, deps);
end function;
