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
    normalizer = API.get_config(jsonapi.api, [:normalizer, :filter])

    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | filter: normalizer.parse_filter(jsonapi, query_params["filter"])}
    )
  end
end
