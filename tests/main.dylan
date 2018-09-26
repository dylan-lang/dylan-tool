Module: pacman-test
Synopsis: pacman test suite main function

define suite pacman-test-suite ()
  test test-catalog;
  test test-latest;
end;

run-test-application(pacman-test-suite);
