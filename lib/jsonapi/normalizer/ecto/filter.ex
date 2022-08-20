defmodule JSONAPI.Normalizer.Ecto.Filter do
  @moduledoc """
  JSON:API 'filter' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'filter' as is, raises otherwise.
  """

  alias JSONAPI.Normalizer

  @behaviour Normalizer.Filter

  @impl Normalizer.Filter
  def parse_filter(%JSONAPI{filter: filter}, nil), do: filter
  def parse_filter(_jsonapi, filter), do: filter
end
