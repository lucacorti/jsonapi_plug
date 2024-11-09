# Changelog

## 2.0.0 "Protocols" (TBA)

`JSONAPIPlug` 2.0 has moved to a protocol based approach to resource definition.
This is the result of a big refactoring, cleaning up internals and providing a more
stable foundation for the library moving forward. This means there are a number of
breaking changes that require changes to applications using `JSONAPIPlug`.

See the [upgrade guide][upgrade] in the docs for detailed upgrade instructions from 1.0.

- `JSONAPIPlug.Resource` is now a protocol instead of a behaviour.
  Using structs as resource data is now mandatory.
- Moved `path` option from `JSONAPI.Resource` to `JSONAPIPlug.Plug`.
- Passing functions to `JSONAPIPlug.Resource` attribute `serialize`
  and `deserialize` to customize attribute value serialization and
  deserialization has been replaced by `JSONAPIPlug.Resource.Attribute`.
- Generating per-resource `JSON:API` links and meta with `JSONAPIPlug.Resource`
  callbacks has been replaces by the `JSONAPIPlug.Resource.Links` and
  `JSONAPIPlug.Resource.Meta` protocols.
- Removed `links` option to `JSONAPIPlug.API`. Resource links are always generated.
- Moved the Phoenix render function to a component module in the library, thiis can
  be added to the phoenix `MyAppWeb` module and imported in the phoenix `_json.ex`
  module via `use MyAppWeb, :jsonapi` as per phoenix conventions.
- Enforce `client_generated_ids` option. This prevents sending ids in resources and
  included resources when `client_generated_ids` is turned off. If you were sending
  ids to support resource creation with included atomically, this is now supported
  by sending `JSON:API 1.1` `lid` in relationships and included resources. This
  is supported even though the reported jsonapi vesion is still `1.0` because the
  library still doesn't have full `JSON:API 1.1` support. Only `lid` is supported.

Contributors: @lucacorti

## 1.0.7 (2024-09-23)

- Fix case in deserialization of relationships (@treere)

## 1.0.6 (2024-05-24)

- Fix deserialization of many relationships (@lucacorti, @alexgolasibill)

## 1.0.5 (2024-01-30)

- Allow disabling generation of links for relationships and includes. (@treere)
- Add compile time optimizations for case transformation of resource fields (@treere)
- Add support to restrict allowed includes to `JSONAPIPlug.Plug`. (@lucacorti)

## 1.0.4 (2023-10-23)

- Fix deeply nested includes not always serialized correctly (@treere)

## 1.0.3 (2023-04-28)

- Accept id along with attributes in default sort parser implementation (@agos)
- Remove deprecated builder_opts() usage from Plug.Builder (@lucacorti)

## 1.0.2 (2023-04-14)

- Cache configuration (profiling by @treere, @lucacorti)
- Relax :nimble_options dependency (@lucacorti)

## 1.0.1 (2023-03-15)

- Allow nimble options 1.0 (@lucacorti)

## 1.0.0 "Garetto Basso" (2023-02-18)

First release of `jsonapi_plug`: `JSON:API` library for Plug and Phoenix applications.

This project was born as a fork of the [jsonapi](https://github.com/beam-community/jsonapi)
library but has since been completely rewritten and is a different project.

What `jsonapi_plug` has to offer to users of Phoenix/Plug for building `JSON:API` compliant APIs:

- An extensible system based on behaviours to convert `JSON:API` payloads and query parameters from/to whatever format best suits the library user. Default implementations are provided to convert payloads and query parameters to an Ecto friendly format, which is probably the most common scenario for the data source of APIs in Phoenix based applications. Behaviours are available to customize parsing and/or easily parse non-standard specified query parameters (filter, page).
- Ability to have multiple APIs with different configurations sourced from the hosting application configuration to avoid single global configuration rigidity. This allows to serve multiple different APIs from a single Phoenix/Plug application instance.
- A declarative resource system allowing users to control rendering, rename fields between `JSON:API` payloads and internal data, customize (de)serialization of fields values and more without writing additional business logic code.

Contributors: @lucacorti

[upgrade]: https://hexdocs.pm/jsonapi_plug/upgrading.html
