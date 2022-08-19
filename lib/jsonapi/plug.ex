defmodule JSONAPI.Plug do
  @moduledoc """
  JSON:API Plug
  """

  @options_schema api: [
                    doc: "A module use-ing `JSONAPI.API` to provide configuration",
                    type: :atom,
                    required: true
                  ]

  @typedoc """
  Processes configuration options. Available options are:

  #{NimbleOptions.docs(@options_schema)}
  """
  @type options :: keyword()

  use Plug.Builder

  plug :config_api, builder_opts()
  plug JSONAPI.Plug.ContentTypeNegotiation
  plug JSONAPI.Plug.FormatRequired
  plug JSONAPI.Plug.IdRequired
  plug JSONAPI.Plug.ResponseContentType

  @doc false
  def config_api(conn, options) do
    NimbleOptions.validate!(options, @options_schema)

    {api, _options} = Keyword.pop(options, :api)

    put_private(conn, :jsonapi, %JSONAPI{api: api})
  end
end
