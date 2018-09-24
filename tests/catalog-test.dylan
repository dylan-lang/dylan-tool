Module: pacman-test

define function raw-parser (s :: <string>) => (_ :: <string>) s end;

define constant $catalog-json =
  #raw:({
         "__catalog_attributes": {},
         "http": {
                  "contact": "zippy",
                  "description": "foo",
                  "license-type": "MIT",
                  "synopsis": "HTTP server and client",
                  "category": "network",
                  "keywords": [ "http" ],
                  "versions": {
                               "1.0.0": {
                                         "deps": [ "uri/4.0.9", "opendylan/2014.1.0" ],
                                         "source-url": "https://github.com/dylan-lang/http"
                                        },
                               "2.10.0": {
                                         "deps": [ "strings/2.3.3", "uri/6.1.0", "opendylan/2018.0.2" ],
                                         "source-url": "https://github.com/dylan-lang/http"
}
                                 }
                    },
         "json": {
                  "contact": "me@mine",
                  "description": "bar",
                  "license-type": "BSD",
                  "synopsis": "json parser/serializer",
                  "category": "encoding",
                  "keywords": [ "parser", "config", "serialize" ],
                  "versions": {
                               "1.0.0": {
                                         "deps": [ "opendylan/2014.1.0" ],
                                         "source-url": "https://github.com/dylan-lang/json"
                                        },
                               "3.1234.100": {
                                              "deps": [ "strings/2.3.3", "opendylan/2018.0.2" ],
                                              "source-url": "https://github.com/dylan-lang/json"
                                             }
                                 }
                    }
           });

define test test-json-to-catalog ()
  let catalog = json-to-catalog(parse-json($catalog-json));
end;
