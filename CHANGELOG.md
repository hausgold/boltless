### next

* TODO: Replace this bullet point with an actual description of a change.

### 1.4.0

* Moved the development dependencies from the gemspec to the Gemfile (#4)
* Dropped support for Ruby <2.7 (#5)

### 1.3.0

* Added support for Gem release automation

### 1.2.0

* Bundler >= 2.3 is from now on required as minimal version (#2)
* Dropped support for Ruby < 2.5 (#2)
* Dropped support for Rails < 5.2 (#2)
* Updated all development/runtime gems to their latest
  Ruby 2.5 compatible version (#2)

### 1.1.0

* Added a raw response handler hook which allows to check/modify the neo4j
  response body before it gets JSON parsed
  (`Boltless.configuration.raw_response_handler`) (#1)

### 1.0.0

* Initial gem implementation
* Full support for the neo4j HTTP API/Cypher transaction API
* Added helpers to build injection-free Cypher statements
* Documented the whole gem and all its features
