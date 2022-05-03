Module: dylan-tool-commands
Synopsis: Utilities for use by dylan-tool commands


// Run an executable or shell command. `command` may be a string or a sequence
// of strings. If a string it is run with `/bin/sh -c`. If a sequence of
// strings the first element is the executable pathname. Returns the exit
// status of the command and the combined output to stdout and stderr.
define function run
    (command :: <seq>, #key working-directory :: false-or(<directory-locator>))
 => (status :: <int>, output :: <string>)
  let stream = make(<string-stream>, direction: #"output");
  let status = os/run(command,
                      under-shell?: instance?(command, <string>),
                      working-directory: working-directory,
                      outputter: method (string, #rest ignore)
                                   write(stream, string)
                                 end);
  values(status, stream.stream-contents)
end function;
