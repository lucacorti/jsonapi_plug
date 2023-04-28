# Changelog

## 1.0.3 (2023-04-28)

Accept id along with attributes in default sort parser implementation (@agos)
Remove deprecated builder_opts() usage from Plug.Builder (@lucacorti)

## 1.0.2 (2023-04-14)

Cache configuration (profiling by @treere, @lucacorti)
Relax :nimble_options dependency (@lucacorti)

## 1.0.1 (2023-03-15)

Allow nimble options 1.0 (@lucacorti)

## 1.0.0 "Garetto Basso" (2023-02-18)

First release of `jsonapi_plug`: `JSON:API` library for Plug and Phoenix applications.

This project was born as a fork of the [jsonapi](https://github.com/beam-community/jsonapi)
library but has since been completely rewritten and is a different project.

What `jsonapi_plug` has to offer to users of Phoenix/Plug for building `JSON:API` compliant APIs:

- An extensible system based on behaviours to convert `JSON:API` payloads and query parameters from/to whatever format best suits the library user. Default implementations are provided to convert payloads and query parameters to an Ecto friendly format, which is probably the most common scenario for the data source of APIs in Phoenix based applications. Behaviours are available to customize parsing and/or easily parse non-standard specified query parameters (filter, page).
- Ability to have multiple APIs with different configurations sourced from the hosting application configuration to avoid single global configuration rigidity. This allows to serve multiple different APIs from a single Phoenix/Plug application instance.
- A declarative resource system allowing users to control rendering, rename fields between `JSON:API` payloads and internal data, customize (de)serialization of fields values and more without writing additional business logic code.

Contributors: @lucacorti
