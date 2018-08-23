Module: package-manager
Synopsis: Package installation and download

define method download-version
    (mgr :: <manager>, pkg :: <package>, version :: <version>, dest-dir :: <directory-locator>) => ()
  do-stuff()
end method download-version;

define method install-version
    (mgr :: <manager>, pkg :: <package>, version :: <version>) => ();
  download-version(mgr, pkg, version, installation-directory(mgr, pkg, version));
end method install-version;
