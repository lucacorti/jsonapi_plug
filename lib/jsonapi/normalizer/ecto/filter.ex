defmodule JSONAPI.Normalizer.Ecto.Filter do
  @moduledoc """
  JSON:API 'filter' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'filter' as is if it is a map, raises otherwise.
  """

  alias JSONAPI.{Exceptions.InvalidQuery, Normalizer}

  @behaviour Normalizer.Filter

  @impl Normalizer.Filter
  def parse_filter(%JSONAPI{filter: filter}, nil), do: filter

  def parse_filter(_jsonapi, filter) when is_map(filter), do: filter

  def parse_filter(%JSONAPI{view: view}, filter) do
    raise InvalidQuery, type: view.type(), param: :filter, value: filter
  end
end
