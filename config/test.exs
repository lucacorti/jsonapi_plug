import Config

alias JSONAPIPlug.TestSupport.API.{
  DasherizingAPI,
  DefaultAPI,
  OtherHostAPI,
  OtherNamespaceAPI,
  OtherSchemeAPI,
  UnderscoringAPI
}

alias JSONAPIPlug.TestSupport.Pagination.PageBasedPagination

config :jsonapi_plug, DasherizingAPI, case: :dasherize
config :jsonapi_plug, DefaultAPI, pagination: PageBasedPagination
config :jsonapi_plug, OtherHostAPI, host: "www.otherhost.com"
config :jsonapi_plug, OtherNamespaceAPI, namespace: "somespace"
config :jsonapi_plug, OtherPortAPI, port: 42
config :jsonapi_plug, OtherSchemeAPI, scheme: :https
config :jsonapi_plug, UnderscoringAPI, case: :underscore
