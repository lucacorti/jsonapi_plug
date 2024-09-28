# Upgrading

Upgrade instructions between major versions of `JSONAPIPlug`.

## JSONAPIPlug 1.0 to 2.0

### What's changed

- `JSONAPIPlug.Resource` is now a protocol instead of a behaviour.
  Using structs as resource data is now mandatory.
- Passing functions to `JSONAPIPlug.Resource` attribute `serialize`
  and `deserialize` to customize attribute value serialization and
  deserialization has been replaced by the `JSONAPIPlug.Resource.Attribute`
  protocol.
- Moved `path` option from `JSONAPI.Resource` to `JSONAPIPlug.Plug`.
- Removed `links` option to `JSONAPIPlug.API`. Resource links are always generated.
- Moved the Phoenix render function to a component module in the library, is can be added to the phoenix `MyAppWeb` module
  and imported in the phoenix `_json.ex` module via `use MyAppWeb, :jsonapi` as per phoenix conventions.

### Migration

  1. Replace all `use JSONAPIPlug.Resource, ...options...` in your `_json.ex` files with one of:
    - `@derive {JSONAPIPlug.Resource, ...options...}` in the module defining your structs.
    - `require Protocol` and `Protocol.derive(JSONAPIPlug.Resource, MyStruct, ...options...)`
      if you prefer to keep it in the `_json.ex` modules.
    - Provide a manual implementation of `JSONAPIPlug.Resource`. This is discouraged
      because the derivation macro generates functions for recasing and options that are tedious to
      implement manually.
  2. Move the `path` option from `JSONAPIPlug.Resource` options to `plug JSONAPIPlug.Plug` options in your controllers.
  3. `JSONAPIPlug.Resource` attribute options `serialize` and `deserialize` now only support a boolean value.
      Replace all function references passed to `serialize` and `deserialize` with an implementation
      of the `JSONAPIPlug.Resource.Attribute` protocol for your resource.
  4. If overridden, replace the `JSONAPIPlug.Resource.links` callback with an implementation of the
     `JSONAPIPlug.Resource.Links` protocol for your resource to provide per-resource `JSON:API` links.
  5. If overridden, replace the `JSONAPIPlug.Resource.meta` callback with an implementation of the
    `JSONAPIPlug.Resource.Meta` protocol for your resource to provide per-resource `JSON:API` meta.
  6. If you use phonenix, either call `JSONAPIPlug.render/5` in your controllers or add `use MyAppWeb, :json_api`
     to your `_json.ex` modules and call `render/3`. See the README for complete instructions.
