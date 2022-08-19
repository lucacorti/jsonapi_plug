import Config

alias JSONAPI.TestSupport.{
  APIs.DasherizingAPI,
  APIs.DefaultAPI,
  APIs.OtherHostAPI,
  APIs.OtherNamespaceAPI,
  APIs.OtherSchemeAPI,
  APIs.UnderscoringAPI,
  Pagination.PageBasedPagination
}

config :jsonapi, DasherizingAPI, case: :dasherize
config :jsonapi, DefaultAPI, pagination: PageBasedPagination
config :jsonapi, OtherHostAPI, host: "www.otherhost.com"
config :jsonapi, OtherNamespaceAPI, namespace: "somespace"
config :jsonapi, OtherPortAPI, port: 42
config :jsonapi, OtherSchemeAPI, scheme: :https
config :jsonapi, UnderscoringAPI, case: :underscore
