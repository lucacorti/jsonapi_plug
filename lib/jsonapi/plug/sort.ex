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
    normalizer = API.get_config(jsonapi.api, [:normalizer, :sort])

    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | sort: normalizer.parse_sort(jsonapi, query_params["sort"])}
    )
  end
end
