# Low-tech Makefile to build and install dylan-tool.

# Because there's currently no way to make a static executable this gets
# installed with the following directory structure:
#
#   ${DYLAN}/install/dylan-tool/bin/dylan-tool          # dylan-tool executable
#   ${DYLAN}/install/dylan-tool/lib/*                   # dylan-tool used libraries
#   ${DYLAN}/bin/dylan                                  # symlink
#      -> ../install/dylan-tool/bin/dylan-tool          #   to here
#
# So just make sure ${DYLAN}/bin is on your path.

install_dir     = $(DYLAN)/install/dylan-tool
install_bin     = $(install_dir)/bin
install_lib     = $(install_dir)/lib
link_target     = $(install_bin)/dylan-tool
link_source     = $(DYLAN)/bin/dylan

build:
	dylan-compiler -build dylan-tool

install: build
	@if [ -z "$${DYLAN}" ]; then \
	  echo "The \$$DYLAN environment variable must be set."; \
	  exit 1; \
	fi;
	mkdir -p $(install_bin)
	mkdir -p $(install_lib)
	cp _build/bin/dylan-tool $(install_bin)/
	cp -r _build/lib/lib* $(install_lib)/
	mkdir -p $(DYLAN)/bin
	@if [ ! -L "$(link_source)" ]; then \
	  ln -s $(link_target) $(link_source); \
	fi;

clean:
	rm -rf _build

distclean: clean
	rm -rf $(install_dir)
	rm -f $(link_source)
