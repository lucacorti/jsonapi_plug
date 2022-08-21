defmodule JSONAPI.Normalizer.Page do
  @moduledoc """
  Normalize JSON:API 'page' query parameter to a user defined format
  """

  alias Plug.Conn

  @doc "Transforms the value of the JSON:API 'page' query parameter"
  @callback parse_page(JSONAPI.t(), Conn.query_param()) :: term() | no_return()
end
