# Changelog

## 1.0.0 "Garetto Basso" (2022-09-01)

First release of `jsonapi_plug`: `JSON:API` library for Plug and Phoenix applications.

This project was born as a fork of the [jsonapi](https://github.com/beam-community/jsonapi)
library but has since been completely rewritten and is now a completely different project.

What `jsonapi_plug` has to offer to users of Phoenix/Plug for quickly building `JSON:API` compliant APIs:

- An extensible system based on behaviours to convert `JSON:API` payloads and query parameters from/to whatever format best suits the library user. Default implementations are provided to convert payloads and query parameters to an Ecto friendly format, which is probably the most common scenario for the data source of APIs in Phoenix based applications. Behaviours are available to customize parsing and/or easily parse non-standard specified query parameters (filter, page).
- Ability to have multiple APIs with different configurations sourced from the hosting application configuration to avoid single global configuration rigidity. This allows to serve multiple different APIs from a single Phoenix/Plug application instance.
- A declarative view system allowing users to control rendering, rename fields between `JSON:API` payloads and internal data, customize (de)serialization of fields values and more without writing additional business logic code.

### Contributors

@lucacorti
