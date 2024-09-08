defmodule JSONAPIPlug.QueryParser.Ecto.Fields do
  @moduledoc """
  JSON:API 'fields' query parameter parser implementation for Ecto

  Expects `include` parameter to in the [JSON:API fields](https://jsonapi.org/format/#fetching-sparse-fieldsets)
  format and converts the specification format to a map of fields list format for ease of
  use with `select` option to `Ecto.Repo` functions.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, Resource}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, nil), do: %{}

  def parse(%JSONAPIPlug{resource: resource}, fields) when is_map(fields) do
    Enum.reduce(fields, %{}, fn {type, value}, validated_fields ->
      valid_fields =
        resource
        |> attributes_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",", trim: true)
          |> Enum.into(
            MapSet.new(),
            &String.to_existing_atom(JSONAPIPlug.recase(&1, :underscore))
          )
        rescue
          ArgumentError ->
            reraise InvalidQuery.exception(
                      type: Resource.type(resource),
                      param: "fields",
                      value: inspect(fields)
                    ),
                    __STACKTRACE__
        end

      size = MapSet.size(requested_fields)

      case MapSet.subset?(requested_fields, valid_fields) do
        false when size > 0 ->
          raise InvalidQuery,
            type: Resource.type(resource),
            param: "fields",
            value: inspect(fields)

        _ ->
          Map.put(validated_fields, type, MapSet.to_list(requested_fields))
      end
    end)
  end

  def parse(%JSONAPIPlug{resource: resource}, fields) do
    raise InvalidQuery, type: Resource.type(resource), param: "fields", value: inspect(fields)
  end

  defp attributes_for_type(resource, type) do
    if Resource.type(resource) == type do
      Resource.attributes(resource)
    else
      case resource_for_related_type(resource, type) do
        nil ->
          raise InvalidQuery, type: Resource.type(resource), param: "fields", value: type

        related_resource ->
          Resource.attributes(related_resource)
      end
    end
  end

  defp resource_for_related_type(resource, type) do
    Resource.relationships(resource)
    |> Enum.find_value(fn relationship ->
      related_resource_module = Resource.field_option(resource, relationship, :resource)

      unless is_nil(related_resource_module) do
        related_resource = struct(related_resource_module)
        Resource.type(related_resource) == type && related_resource
      end
    end)
  end
end
