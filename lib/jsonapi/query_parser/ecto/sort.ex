defmodule JSONAPI.QueryParser.Ecto.Sort do
  @moduledoc """
  JSON:API 'sort' query parameter normalizer implementation for Ecto

  Expects sort parameters to be specified as an ordered comma separated list
  of resource attributes to sort the response by. The order is descending
  unless a '-' is prefixed to the attribute name.

  Examples:

  /?sort=createdAt
  /?sort=-createdAt,name
  /?sort=-name
  """
  alias JSONAPI.{Exceptions.InvalidQuery, QueryParser, View}

  @behaviour QueryParser

  @impl QueryParser
  def parse(%JSONAPI{sort: sort}, nil), do: sort

  def parse(%JSONAPI{view: view}, sort) when is_binary(sort) do
    valid_sort_fields =
      view.attributes()
      |> Enum.map(&to_string(View.field_option(&1, :name) || View.field_name(&1)))

    sort
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn field ->
      [_, direction, name] = Regex.run(~r/(-?)(\S*)/, field)

      unless name in valid_sort_fields do
        raise InvalidQuery, type: view.type(), param: :sort, value: field
      end

      build_sort(direction, String.to_existing_atom(name))
    end)
  end

  def parse(%JSONAPI{view: view}, sort) do
    raise InvalidQuery, type: view.type(), param: :sort, value: inspect(sort)
  end

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]
end
