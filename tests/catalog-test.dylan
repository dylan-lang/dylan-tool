Module: pacman-test

define constant $catalog-text =
  #:string:({
    "__catalog_attributes": {"unused": "for now"},
    "http": {
      "contact": "zippy",
      "description": "foo",
      "license-type": "MIT",
      "summary": "HTTP server and client",
      "category": "network",
      "keywords": [ "http" ],
      "releases": {
        "1.0.0": {
          "deps": [ "uri 4.0.9", "opendylan 2014.2.2" ],
          "location": "https://github.com/dylan-lang/http"
        },
        "2.10.0": {
          "deps": [ "strings 2.3.4", "uri 6.1.0", "opendylan 2018.0.2" ],
          "location": "https://github.com/dylan-lang/http"
        }
      }
    },
    "json": {
      "contact": "me@mine",
      "description": "bar",
      "license-type": "BSD",
      "summary": "json parser/serializer",
      "category": "encoding",
      "keywords": [ "parser", "config", "serialize" ],
      "releases": {
        "1.0.0": {
          "deps": [ "opendylan 2014.1.0" ],
          "location": "https://github.com/dylan-lang/json"
        },
        "3.1234.100": {
          "deps": [ "strings 3.4.5", "opendylan 2018.8.8" ],
          "location": "https://github.com/dylan-lang/json"
        }
      }
    }
  });

define function get-test-catalog () => (_ :: <catalog>)
  with-input-from-string (in = $catalog-text)
    read-json-catalog(in /* table-class: <ordered-string-table> */)
  end
end;

define test test-read-json-catalog ()
  let cat = get-test-catalog();
  assert-equal(#["http", "json"], sort(cat.package-names));
  let http = find-package-release(cat, "http", string-to-version("2.10.0"));
  assert-true(http);
  assert-equal("MIT", http.package-license-type);
  assert-equal("opendylan", http.release-deps[2].package-name);
end;

define test test-find-latest-version ()
  let cat = get-test-catalog();
  let json = find-package-release(cat, "json", $latest);
  assert-true(json);
  assert-equal("3.1234.100", version-to-string(json.release-version));
end;

define test test-validate-dependencies ()
  // needs more...
  assert-signals(<catalog-error>, validate-catalog(get-test-catalog()));
end;

define test test-load-catalog ()
  // TODO: Need a way to make test data files available to the tests.  This
  // test requires network access and an account on GitHub.  For now, to make
  // this test pass you need to set DYLAN_CATALOG to the file containing the
  // catalog in your checkout.
  assert-no-errors(load-catalog());
end;
