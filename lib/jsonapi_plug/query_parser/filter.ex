defmodule JSONAPIPlug.QueryParser.Filter do
  @moduledoc """
  JSON:API 'filter' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'filter' as is, raises otherwise.
  """

  alias JSONAPIPlug.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, filter), do: filter
end
