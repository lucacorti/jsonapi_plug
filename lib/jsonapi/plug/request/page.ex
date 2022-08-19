defmodule JSONAPI.Plug.Request.Page do
  @moduledoc """
  Plug for parsing the 'page' JSON:API query parameter
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
      %JSONAPI{jsonapi | page: parse_page(jsonapi, query_params["page"])}
    )
  end

  defp parse_page(%JSONAPI{page: page}, nil), do: page

  defp parse_page(_jsonapi, page) when is_map(page), do: page

  defp parse_page(%JSONAPI{view: view}, page) do
    raise InvalidQuery, type: view.type(), param: :page, value: inspect(page)
  end
end
