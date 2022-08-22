defmodule JSONAPIPlug.QueryParser.Filter do
  @moduledoc """
  JSON:API 'filter' query parameter parser

  Since the specification does not define the format for the [JSON:API filter](http://jsonapi.org/format/#fetching-filtering)
  parameter, the default implementation just returns the value of 'filter' as is.
  """

  alias JSONAPIPlug.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, filter), do: filter
end
