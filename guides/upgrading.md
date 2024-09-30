# Upgrading

Upgrade instructions between major versions of `JSONAPIPlug`.

## Upgrading from 1.x to 2.0

  To upgrade your application to 2.0:

  1. Replace all `use JSONAPIPlug.Resource, ...options...` in your `_json.ex` files with one of:
    - `@derive {JSONAPIPlug.Resource, ...options...}` in the module defining your structs.
    - `require Protocol` and `Protocol.derive(JSONAPIPlug.Resource, MyStruct, ...options...)`
      if you prefer to keep it in the `_json.ex` modules.
    - Provide a manual implementation of `JSONAPIPlug.Resource`. This is discouraged
      because the derivation macro generates functions for recasing and options that are tedious to
      implement manually.
  2. Move the `path` option from `JSONAPIPlug.Resource` options to `JSONAPIPlug.Plug` options in your controllers.
  3. `JSONAPIPlug.Resource` attribute options `serialize` and `deserialize` now only support a boolean value.
      Remove all function references passed to `serialize` and `deserialize` and provide an implementation
      of the `JSONAPIPlug.Resource.Attribute` protocol for your resource to do custom serialization/deserialization.
  4. If overridden, replace the `JSONAPIPlug.Resource.links` callback with an implementation of the
     `JSONAPIPlug.Resource.Links` protocol for your resource to add per-resource `JSON:API` links.
  5. If overridden, replace the `JSONAPIPlug.Resource.meta` callback with an implementation of the
    `JSONAPIPlug.Resource.Meta` protocol for your resource to add per-resource `JSON:API` meta.
  6. If you use phonenix, either call `JSONAPIPlug.render/5` in your controllers or add `use MyAppWeb, :json_api`
     to your `_json.ex` modules and call `render/3`. See the README for complete instructions.
  7. If you are sending resource `ids` in `included` for resource create requests, this is now forbidden unless
     the `client_generated_ids` option is configured on your `JSONAPIPlug.API`. You can however use `JSON:API 1.1`
     `lid` in relationships and included resources if you whish to create resources with included resources atomically.
     Please note that this works even though the reported `JSON:API` version is still `1.0`, because the library still
     does not support the full `JSON:API 1.1` specification yet, only `lid` is supported for now.
