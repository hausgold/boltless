### next

* Added a raw response handler hook which allows to check/modify the neo4j
  response body before it gets JSON parsed
  (`Boltless.configuration.raw_response_handler`) (#1)

### 1.0.0

* Initial gem implementation
* Full support for the neo4j HTTP API/Cypher transaction API
* Added helpers to build injection-free Cypher statements
* Documented the whole gem and all its features
