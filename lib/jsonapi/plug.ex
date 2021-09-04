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
    assign(conn, :jsonapi, %JSONAPI{api: Keyword.get(opts, :api)})
  end
end
