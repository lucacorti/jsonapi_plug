defmodule JSONAPIPlug.QueryParser.Ecto.Sort do
  @moduledoc """
  JSON:API 'sort' query parameter parser implementation for Ecto

  Expects sort parameters to be in the *recommended* [JSON:API sort](https://jsonapi.org/format/#fetching-sorting)
  format and converts them to Ecto `order_by` format for ease of use.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, Resource}

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

  def parse(%JSONAPIPlug{} = jsonapi_plug, sort) do
    raise InvalidQuery,
      type: Resource.type(jsonapi_plug.resource),
      param: "sort",
      value: inspect(sort)
  end

  defp parse_sort_field(field_name, resource) do
    field_name
    |> Resource.recase(:underscore)
    |> String.trim_leading("-")
    |> String.split(".", trim: true)
    |> parse_sort_components(resource, [])
  end

  defp parse_sort_components([field_name], resource, components) do
    valid_attributes =
      Enum.map(
        [Resource.id_attribute(resource) | Resource.attributes(resource)],
        &to_string(Resource.field_option(&1, :name) || Resource.field_name(&1))
      )

    unless field_name in valid_attributes do
      raise InvalidQuery, type: Resource.type(resource), param: "sort", value: field_name
    end

    [field_name | components]
    |> Enum.reverse()
    |> Enum.join("_")
    |> String.to_existing_atom()
  end

  defp parse_sort_components([field_name | rest], resource, components) do
    related_resource =
      Resource.relationships(resource)
      |> Enum.find_value(fn relationship ->
        relationship_name =
          to_string(
            Resource.field_option(relationship, :name) || Resource.field_name(relationship)
          )

        field_name == relationship_name &&
          struct(Resource.field_option(relationship, :resource))
      end) || raise InvalidQuery, type: Resource.type(resource), param: "sort", value: field_name

    parse_sort_components(rest, related_resource, [field_name | components])
  end
end
