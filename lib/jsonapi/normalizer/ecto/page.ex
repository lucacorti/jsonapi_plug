defmodule JSONAPI.Normalizer.Ecto.Page do
  @moduledoc """
  JSON:API 'page' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'page' as received in the request.
  """

  alias JSONAPI.Normalizer

  @behaviour Normalizer.Page

  @impl Normalizer.Page
  def parse_page(%JSONAPI{page: page}, nil), do: page
  def parse_page(_jsonapi, page), do: page
end
