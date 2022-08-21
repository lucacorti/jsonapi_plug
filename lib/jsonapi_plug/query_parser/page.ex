defmodule JSONAPIPlug.QueryParser.Page do
  @moduledoc """
  JSON:API 'page' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'page' as received in the request.
  """

  alias JSONAPIPlug.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, page), do: page
end
