defmodule JSONAPI.QueryParser do
  @moduledoc """
  Parses a JSON:API query parameter to a user defined format.

  You can user the query parser to implement custom parsing for JSON:API
  query parameters that do not define a standard format: filter, page and sort.
  The parsed value will be stored in the corresponding attribute of the `JSONAPI`
  struct. If an error is encountered during parsing, you can raise
  `JSONAPI.Exceptions.InvalidQuery` to return a standard JSON:API error to the client.
  """

  alias Plug.Conn

  @doc "Transforms the value of the JSON:API 'filter' query parameter"
  @callback parse(JSONAPI.t(), Conn.query_param()) :: term() | no_return()
end
