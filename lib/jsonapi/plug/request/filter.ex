defmodule JSONAPI.Plug.Request.Filter do
  @moduledoc """
  Plug for parsing the 'filter' JSON:API query parameter
  """

  alias JSONAPI.Exceptions.InvalidQuery
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
      %JSONAPI{jsonapi | filter: parse_filter(jsonapi, query_params["filter"])}
    )
  end

  defp parse_filter(%JSONAPI{filter: filter}, nil), do: filter

  defp parse_filter(_jsonapi, filter) when is_map(filter), do: filter

  defp parse_filter(%JSONAPI{view: view}, filter) do
    raise InvalidQuery, type: view.type(), param: :filter, value: filter
  end
end
