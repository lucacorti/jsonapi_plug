import Config

alias JSONAPI.TestSupport.APIs.{
  DasherizingAPI,
  DefaultAPI,
  OtherHostAPI,
  OtherNamespaceAPI,
  OtherSchemeAPI,
  UnderscoringAPI
}

alias JSONAPI.TestSupport.Pagination.PageBasedPagination

config :jsonapi, DasherizingAPI, inflection: :dasherize
config :jsonapi, DefaultAPI, pagination: PageBasedPagination
config :jsonapi, OtherHostAPI, host: "www.otherhost.com"
config :jsonapi, OtherNamespaceAPI, namespace: "somespace"
config :jsonapi, OtherPortAPI, port: 42
config :jsonapi, OtherSchemeAPI, scheme: :https
config :jsonapi, UnderscoringAPI, inflection: :underscore
