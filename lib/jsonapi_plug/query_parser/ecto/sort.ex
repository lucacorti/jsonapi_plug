defmodule JSONAPIPlug.QueryParser.Ecto.Sort do
  @moduledoc """
  JSON:API 'sort' query parameter parser implementation for Ecto

  Expects sort parameters to be in the *recommended* [JSON:API sort](https://jsonapi.org/format/#fetching-sorting)
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
    |> Enum.map(fn name ->
      direction = if String.starts_with?(name, "-"), do: :desc, else: :asc

      field_name =
        name
        |> String.trim_leading("-")
        |> JSONAPIPlug.recase(:underscore)

      unless field_name in valid_sort_fields do
        raise InvalidQuery, type: jsonapi_plug.view.type(), param: :sort, value: name
      end

      {direction, String.to_existing_atom(field_name)}
    end)
  end

  def parse(%JSONAPIPlug{view: view}, sort) do
    raise InvalidQuery, type: view.type(), param: :sort, value: inspect(sort)
  end
end
