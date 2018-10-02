Module: pacman-test
Synopsis: pacman test suite main function

define suite pacman-test-suite ()
  test test-catalog;
  test test-latest;
  test test-install;
  test test-dep-name;
  test test-bad-dep-versions;
  test test-good-dep-versions;
end;

run-test-application(pacman-test-suite);
