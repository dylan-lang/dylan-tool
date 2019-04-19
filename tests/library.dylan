module: dylan-user

define library workspaces-tests
  use common-dylan;
  use json;
  use system,
    import: { file-system, locators };
  use testworks;
  use workspaces;
end;

define module workspaces-tests
  use common-dylan;
  use file-system,
    prefix: "fs/";
  use json,
    import: { parse-json => json/parse };
  use locators;
  use testworks;
  use workspaces,
    prefix: "ws/";
end;
