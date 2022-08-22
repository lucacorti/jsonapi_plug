# Changelog

## 1.0.0 (2022-09-01)

First release of `jsonapi_plug`. This started as a fork of the `jsonapi` library but has been completely rewritten in order to have more flexibility.

- Changed:
  - An extensible system based on behaviours to convert `JSON:API` payloads and query parameters from/to whatever format best suits the library user.
  - Default implementations provided by this library are included to convert payload and standard format query parameters (fields, include, sort) to an Ecto friendly format, which is probably the most common scenario for the data source of APIs in Phoenix based applications. Behaviours are also provided to preprocess non-standard specified query parameters (filter, page) for ease of consumption by the user.
  - Ability to have multiple APIs with different configuration, sourced from the hosting application configuration to avoid single global configuration rigidity.
  - A view attribute/resource options system allowing users to rename fields between `JSON:API` payloads and internal data, customize serialization and deserialization of values directly from `JSONAPIPlug.View` in a declarative way.
  - Cleanups, removal and reimplementation of internal APIs to ease maintenance and extensions.

### Contributors

Just me: @lucacorti
