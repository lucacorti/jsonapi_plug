defmodule JSONAPIPlug.QueryParser do
  @moduledoc """
  Parses a JSON:API query parameter to a user defined format.

  You can implement a custom format for JSON:API query parameters that do not define
  a standard format: filter, page and sort.

  To customize the default parser implement a module adopting the `JSONAPIPlug.QueryParser`
  behaviour for your sort format:

  ```elixir
  defmodule MyApp.API.QueryParsers.Sort do
    ...
    @behaviour JSONAPIPlug.QueryParser

    # Transforms the query parameter value to a user defined format
    @impl JSONAPIPlug.QueryParser
    def parse(jsonapi_plug, sort) do
      ...my sort query parameter parsing logic...
    end
  end
  ```

  and configure it in your API configuration under the `parsers` key.

  ```elixir
  config :my_app, MyApp.API,
    parsers: [
      filter: MyApp.API.QueryParser.Filter,
      page: MyApp.API.QueryParser.Page,
      sort: MyApp.API.QueryParser.Sort
    ]
  ```

  The parsers take the query parameter value as input and its return value is placed under an
  attribute with the same name as the query parameter in the `JSONAPIPlug` structure in the conn
  `private` assigns so that you can retrieve it and use it in your application logic.

  You can return a standard JSON:API error to the client by raising `JSONAPIPlug.Exceptions.InvalidQuery`
  exception at any point in your parser code.
  """

  alias Plug.Conn

  @doc "Transforms the value of the JSON:API 'filter' query parameter"
  @callback parse(JSONAPIPlug.t(), Conn.query_param()) :: term() | no_return()
end
