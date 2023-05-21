import Config

alias JSONAPIPlug.TestSupport.{
  APIs.DasherizingAPI,
  APIs.DefaultAPI,
  APIs.OtherHostAPI,
  APIs.OtherNamespaceAPI,
  APIs.OtherSchemeAPI,
  APIs.UnderscoringAPI
}

config :jsonapi_plug, OtherHostAPI, host: "www.otherhost.com"
config :jsonapi_plug, OtherNamespaceAPI, namespace: "somespace"
config :jsonapi_plug, OtherPortAPI, port: 42
config :jsonapi_plug, OtherSchemeAPI, scheme: :https
