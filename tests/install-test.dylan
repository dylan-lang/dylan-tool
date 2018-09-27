Module: pacman-test


define test install-test ()
  // first pass only works on my machine...generalize later
  let text = #str:(
    {
     "json"
       "contact": "carlgay@gmail.com",
     "description": "json parser and encoder",
     "license-type": "MIT",
     "synopsis": "json",
     "category": "configuration",
     "keywords": [ "config" ],
     "versions": {
                  "1.0.0": {
                            "deps": [],
                            "source-url": "file:///home/cgay/dylan/repo/json"
                           }
                    }
       });
  let cat = with-input-from-string (in = text)
              read-json-catalog(in);
            end;
install-package;
end;
