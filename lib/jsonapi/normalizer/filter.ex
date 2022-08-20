defmodule JSONAPI.Normalizer.Filter do
  @moduledoc """
  Normalize JSON:API 'filter' query parameter to a user defined format
  """

  alias Plug.Conn

  @doc "Transforms the value of the JSON:API 'filter' query parameter"
  @callback parse_filter(JSONAPI.t(), Conn.query_param()) :: term() | no_return()
end
