defmodule JSONAPIPlug.QueryParser.Page do
  @moduledoc """
  JSON:API 'page' query parameter parser

  Since the specification does not define the format for the [JSON:API page](http://jsonapi.org/format/#fetching-filtering)
  parameter, the default implementation just returns the value of 'page' as is.
  """

  alias JSONAPIPlug.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, page), do: page
end
