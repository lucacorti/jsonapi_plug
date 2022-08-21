defmodule JSONAPI.Normalizer.Sort do
  @moduledoc """
  Normalize JSON:API 'page' query parameter to a user defined format
  """

  alias Plug.Conn

  @doc "Transforms the value of the JSON:API 'page' query parameter"
  @callback parse_sort(JSONAPI.t(), Conn.query_param()) :: term() | no_return()
end
