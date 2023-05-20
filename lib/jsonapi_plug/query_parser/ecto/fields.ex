defmodule JSONAPIPlug.QueryParser.Ecto.Fields do
  @moduledoc """
  JSON:API 'fields' query parameter parser implementation for Ecto

  Expects `include` parameter to in the [JSON:API fields](https://jsonapi.org/format/#fetching-sparse-fieldsets)
  format and converts the specification format to a map of fields list format for ease of
  use with `select` option to `Ecto.Repo` functions.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, View}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi_plug, nil), do: %{}

  def parse(%JSONAPIPlug{resource: resource}, fields) when is_map(fields) do
    Enum.reduce(fields, %{}, fn {type, value}, fields ->
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
                      type: resource.type(),
                      param: "fields",
                      value: value
                    ),
                    __STACKTRACE__
        end

      size = MapSet.size(requested_fields)

      case MapSet.subset?(requested_fields, valid_fields) do
        false when size > 0 ->
          raise InvalidQuery,
            type: resource.type(),
            param: "fields",
            value:
              requested_fields
              |> MapSet.difference(valid_fields)
              |> MapSet.to_list()
              |> Enum.join(",")

        _ ->
          Map.put(fields, type, MapSet.to_list(requested_fields))
      end
    end)
  end

  def parse(%JSONAPIPlug{resource: resource}, fields) do
    raise InvalidQuery, type: resource.type(), param: "fields", value: fields
  end

  defp attributes_for_type(resource, type) do
    if type == resource.type() do
      Enum.map(resource.attributes(), &View.field_name/1)
    else
      case View.for_related_type(resource, type) do
        nil -> raise InvalidQuery, type: resource.type(), param: "fields", value: type
        related_resource -> Enum.map(related_resource.attributes(), &View.field_name/1)
      end
    end
  end
end
