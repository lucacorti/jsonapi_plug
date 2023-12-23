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
    sort
    |> String.split(",", trim: true)
    |> Enum.map(fn field_name ->
      direction = if String.starts_with?(field_name, "-"), do: :desc, else: :asc
      {direction, parse_sort_field(field_name, jsonapi_plug.resource)}
    end)
  end

  def parse(%JSONAPIPlug{resource: resource}, sort) do
    raise InvalidQuery, type: resource.type(), param: "sort", value: inspect(sort)
  end

  defp parse_sort_field(field_name, resource) do
    field_name
    |> JSONAPIPlug.recase(:underscore)
    |> String.trim_leading("-")
    |> String.split(".", trim: true)
    |> parse_sort_components(resource, [])
  end

  defp parse_sort_components([field_name], resource, components) do
    valid_attributes =
      Enum.map(
        [resource.id_attribute() | resource.attributes()],
        &to_string(View.field_option(&1, :name) || View.field_name(&1))
      )

    unless field_name in valid_attributes do
      raise InvalidQuery, type: resource.type(), param: "sort", value: field_name
    end

    [field_name | components]
    |> Enum.reverse()
    |> Enum.join("_")
    |> String.to_existing_atom()
  end

  defp parse_sort_components([field_name | rest], resource, components) do
    relationships = resource.relationships()

    valid_relationships =
      Enum.map(
        relationships,
        &to_string(View.field_option(&1, :name) || View.field_name(&1))
      )

    unless field_name in valid_relationships do
      raise InvalidQuery, type: resource.type(), param: "sort", value: field_name
    end

    related_resource =
      Enum.find_value(relationships, fn relationship ->
        String.to_existing_atom(field_name) == View.field_name(relationship) &&
          View.field_option(relationship, :resource)
      end)

    parse_sort_components(rest, related_resource, [field_name | components])
  end
end
