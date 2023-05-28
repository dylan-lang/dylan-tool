# Low-tech Makefile to build and install dylan-tool.

# Building an executable for a library named "dylan" causes a conflict with the
# base dylan library. I want this tool to be named "dylan" on the command line,
# so it's necessary to use a makefile to build and then rename the executable
# during the installation process.

# Because there's currently no way to make a static executable this gets
# installed with the following directory structure:
#
#   ${DYLAN}/install/dylan-tool/bin/dylan-tool          # dylan-tool executable
#   ${DYLAN}/install/dylan-tool/lib/*                   # dylan-tool used libraries
#   ${DYLAN}/bin/dylan                                  # symlink
#      -> ../install/dylan-tool/bin/dylan-tool          #   to here
#
# So just make sure ${DYLAN}/bin (or ${HOME}/dylan/bin, the default) is on your path.

DYLAN		?= $${HOME}/dylan
install_dir     = $(DYLAN)/install/dylan-tool
install_bin     = $(install_dir)/bin
install_lib     = $(install_dir)/lib
link_target     = $(install_bin)/dylan-tool-app
link_source     = $(DYLAN)/bin/dylan

.PHONY: build build-with-version clean install install-debug really-install remove-dylan-tool-artifacts test dist distclean

build: remove-dylan-tool-artifacts
	OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry dylan-compiler -build dylan-tool-app

# Hack to add the version to the binary with git tag info. Don't want this to
# be the normal build because it causes unnecessary rebuilds.
build-with-version: remove-dylan-tool-artifacts
	file="sources/commands/utils.dylan"; \
	  orig=$$(mktemp); \
	  temp=$$(mktemp); \
	  cp -p $${file} $${orig}; \
	  cat $${file} | sed "s,/.__./.*/.__./,/*__*/ \"$$(git describe --tags --always)\" /*__*/,g" > $${temp}; \
	  mv $${temp} $${file}; \
	  OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry dylan-compiler -build dylan-tool-app; \
	  cp -p $${orig} $${file}

# After the next OD release (post 2022.1) this should install a static exe
# built with the -unify flag.
really-install:
	mkdir -p $(install_bin)
	mkdir -p $(install_lib)
	cp _build/bin/dylan-tool-app $(install_bin)/
	cp -r _build/lib/lib* $(install_lib)/
	mkdir -p $(DYLAN)/bin
	@if [ ! -L "$(link_source)" ]; then \
	  ln -s $$(realpath $(link_target)) $$(realpath $(link_source)); \
	fi;

install: build-with-version really-install

# Build and install without the version hacking above.
install-debug: build really-install

# dylan-tool needs to be buildable with submodules so that it can be built on
# new platforms without having to manually install deps.
test: build
	OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry \
	  dylan-compiler -build dylan-tool-test-suite \
	  && DYLAN_CATALOG=ext/pacman-catalog _build/bin/dylan-tool-test-suite

dist: distclean install

# Sometimes I use dylan-tool to develop dylan-tool, so this makes sure to clean
# up its artifacts.
remove-dylan-tool-artifacts:
	rm -rf _packages
	find registry -not -path '*/generic/*' -type f -exec rm {} \;

clean: remove-dylan-tool-artifacts
	rm -rf _build
	rm -rf _test

distclean: clean
	rm -rf $(install_dir)
	rm -f $(link_source)
