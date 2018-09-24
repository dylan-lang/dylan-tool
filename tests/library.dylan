Module: dylan-user

define library pacman-test
  use common-dylan;
  use json;
  use pacman;
  use testworks;
end;

define module pacman-test
  use common-dylan;
  use json;
  use %pacman;
  use pacman;
  use testworks;
end;
