defmodule JSONAPI.Normalizer.Ecto.Page do
  @moduledoc """
  JSON:API 'page' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'page' as is if it is a map, raises otherwise.
  """

  alias JSONAPI.{Exceptions.InvalidQuery, Normalizer}

  @behaviour Normalizer.Page

  @impl Normalizer.Page
  def parse_page(%JSONAPI{page: page}, nil), do: page

  def parse_page(_jsonapi, page) when is_map(page), do: page

  def parse_page(%JSONAPI{view: view}, page) do
    raise InvalidQuery, type: view.type(), param: :page, value: inspect(page)
  end
end
