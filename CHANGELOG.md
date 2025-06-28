### next

* TODO: Replace this bullet point with an actual description of a change.

### 2.0.0 (28 June 2025)

* Corrected some RuboCop glitches ([#12](https://github.com/hausgold/boltless/pull/12))
* Drop Ruby 2 and end of life Rails (<7.1) ([#13](https://github.com/hausgold/boltless/pull/13))

### 1.6.1 (21 May 2025)

* Corrected some RuboCop glitches ([#10](https://github.com/hausgold/boltless/pull/10))
* Upgraded the rubocop dependencies ([#11](https://github.com/hausgold/boltless/pull/11))

### 1.6.0 (30 January 2025)

* Added all versions up to Ruby 3.4 to the CI matrix ([#9](https://github.com/hausgold/boltless/pull/9))

### 1.5.1 (17 January 2025)

* Added the logger dependency ([#8](https://github.com/hausgold/boltless/pull/8))

### 1.5.0 (3 January 2025)

* Raised minimum supported Ruby/Rails version to 2.7/6.1 ([#7](https://github.com/hausgold/boltless/pull/7))

### 1.4.4 (15 August 2024)

* Just a retag of 1.4.1

### 1.4.3 (15 August 2024)

* Just a retag of 1.4.1

### 1.4.2 (9 August 2024)

* Just a retag of 1.4.1

### 1.4.1 (9 August 2024)

* Added API docs building to continuous integration ([#6](https://github.com/hausgold/boltless/pull/6))

### 1.4.0 (8 July 2024)

* Moved the development dependencies from the gemspec to the Gemfile ([#4](https://github.com/hausgold/boltless/pull/4))
* Dropped support for Ruby <2.7 ([#5](https://github.com/hausgold/boltless/pull/5))

### 1.3.0 (24 February 2023)

* Added support for Gem release automation

### 1.2.0 (18 January 2023)

* Bundler >= 2.3 is from now on required as minimal version ([#2](https://github.com/hausgold/boltless/pull/2))
* Dropped support for Ruby < 2.5 ([#2](https://github.com/hausgold/boltless/pull/2))
* Dropped support for Rails < 5.2 ([#2](https://github.com/hausgold/boltless/pull/2))
* Updated all development/runtime gems to their latest
  Ruby 2.5 compatible version ([#2](https://github.com/hausgold/boltless/pull/2))

### 1.1.0 (21 September 2022)

* Added a raw response handler hook which allows to check/modify the neo4j
  response body before it gets JSON parsed
  (`Boltless.configuration.raw_response_handler`) ([#1](https://github.com/hausgold/boltless/pull/1))

### 1.0.0 (15 August 2022)

* Initial gem implementation
* Full support for the neo4j HTTP API/Cypher transaction API
* Added helpers to build injection-free Cypher statements
* Documented the whole gem and all its features
