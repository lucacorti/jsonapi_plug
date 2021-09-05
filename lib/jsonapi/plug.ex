defmodule JSONAPI.Plug do
  @moduledoc """
  JSON:API Configuration Plug
  """
  require Logger

  use Plug.Builder
  plug :config_api, builder_opts()
  plug JSONAPI.Plug.ContentTypeNegotiation
  plug JSONAPI.Plug.FormatRequired
  plug JSONAPI.Plug.IdRequired
  plug JSONAPI.Plug.ResponseContentType

  def config_api(conn, opts) do
    {api, _opts} = Keyword.pop(opts, :api)

    unless api do
      raise "You must pass the :api option to JSONAPI.Plug"
    end

    assign(conn, :jsonapi, %JSONAPI{api: api})
  end
end
