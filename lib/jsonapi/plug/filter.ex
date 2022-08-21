defmodule JSONAPI.Plug.Filter do
  @moduledoc """
  Plug for parsing the 'filter' JSON:API query parameter
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
      %JSONAPI{jsonapi | filter: parse(jsonapi, query_params["filter"])}
    )
  end

  defp parse(%JSONAPI{} = jsonapi, nil), do: jsonapi.filter

  defp parse(jsonapi, filter) do
    parser = API.get_config(jsonapi.api, [:query_parsers, :filter])
    parser.parse(jsonapi, filter)
  end
end
