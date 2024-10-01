defmodule JSONAPIPlug.Plug.QueryParam do
  @moduledoc """
  JSON:API Query Paramter parser plug

  Plug for parsing a JSON:API query parameter via a `JSONAPI.QueryParser` implementation.

  It takes an atom corresponding to the query parameter name to parse as its only option
  and stores the returned value in the `JSONAPIPlug` struct stored in `Plug.Conn` private
  assigns under the `jsonapi_plug` key.
  """

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
    parser = jsonapi_plug.config[:query_parsers][query_param]
    value = Map.get(query_params, to_string(query_param))

    Conn.put_private(
      conn,
      :jsonapi_plug,
      struct(jsonapi_plug, [{query_param, parser.parse(jsonapi_plug, value)}])
    )
  end
end
