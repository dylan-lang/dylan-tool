Module: pacman-test
Synopsis: pacman test suite main function

define suite pacman-test-suite ()
  test test-json-to-catalog;
end;

run-test-application(pacman-test-suite);
