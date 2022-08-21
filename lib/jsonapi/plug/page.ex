defmodule JSONAPI.Plug.Page do
  @moduledoc """
  Plug for parsing the 'page' JSON:API query parameter
  """

  alias JSONAPI.API
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(
        %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, query_params: query_params} = conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | page: parse(jsonapi, query_params["page"])}
    )
  end

  defp parse(%JSONAPI{} = jsonapi, nil), do: jsonapi.page

  defp parse(jsonapi, page) do
    parser = API.get_config(jsonapi.api, [:query_parsers, :page])
    parser.parse(jsonapi, page)
  end
end
