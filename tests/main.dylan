Module: pacman-test
Synopsis: pacman test suite main function

define suite pacman-suite ()
  suite catalog-suite;
  suite install-suite;
  suite types-suite;
end;

run-test-application(pacman-suite);
