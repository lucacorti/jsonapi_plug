defmodule JSONAPIPlug.Plug.QueryParam do
  @moduledoc """
  Plug for parsing a JSON:API query parameter via a `JSONAPI.QueryParser` implementation.
  """

  alias JSONAPIPlug.API
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(query_param), do: query_param

  @impl Plug
  def call(
        %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, query_params: query_params} =
          conn,
        query_param
      ) do
    parser = API.get_config(jsonapi_plug.api, [:query_parsers, query_param])
    value = Map.get(query_params, to_string(query_param))

    Conn.put_private(
      conn,
      :jsonapi_plug,
      struct(jsonapi_plug, [{query_param, parser.parse(jsonapi_plug, value)}])
    )
  end
end
