defmodule JSONAPIPlug.QueryParser.Ecto.Sort do
  @moduledoc """
  JSON:API 'sort' query parameter normalizer implementation for Ecto

  Expects sort parameters to be specified in the recommended [JSON:API sort](https://jsonapi.org/format/#fetching-sorting)
  format and converts them to Ecto `order_by` format for ease of use.
  """
  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, View}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, nil), do: []

  def parse(%JSONAPIPlug{} = jsonapi_plug, sort) when is_binary(sort) do
    valid_sort_fields =
      jsonapi_plug.view.attributes()
      |> Enum.map(&to_string(View.field_option(&1, :name) || View.field_name(&1)))

    sort
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn field ->
      [_, direction, name] = Regex.run(~r/(-?)(\S*)/, field)

      unless name in valid_sort_fields do
        raise InvalidQuery, type: jsonapi_plug.view.type(), param: :sort, value: field
      end

      build_sort(direction, String.to_existing_atom(name))
    end)
  end

  def parse(%JSONAPIPlug{view: view}, sort) do
    raise InvalidQuery, type: view.type(), param: :sort, value: inspect(sort)
  end

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]
end
