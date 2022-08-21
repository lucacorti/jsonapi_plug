defmodule JSONAPI.Plug.Sort do
  @moduledoc """
  Plug for parsing the 'sort' JSON:API query parameter
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
      %JSONAPI{jsonapi | sort: parse(jsonapi, query_params["sort"])}
    )
  end

  defp parse(%JSONAPI{} = jsonapi, nil), do: jsonapi.sort

  defp parse(jsonapi, sort) do
    parser = API.get_config(jsonapi.api, [:query_parsers, :sort])
    parser.parse(jsonapi, sort)
  end
end
