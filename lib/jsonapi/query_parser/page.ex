defmodule JSONAPI.QueryParser.Page do
  @moduledoc """
  JSON:API 'page' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'page' as received in the request.
  """

  alias JSONAPI.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi, page), do: page
end
