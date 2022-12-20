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
    |> Enum.map(fn
      "-" <> field_name ->
        {:desc, parse_sort_field(field_name, jsonapi_plug.view)}

      field_name ->
        {:asc, parse_sort_field(field_name, jsonapi_plug.view)}
    end)
  end

  def parse(%JSONAPIPlug{view: view}, sort) do
    raise InvalidQuery, type: view.type(), param: "sort", value: inspect(sort)
  end

  defp parse_sort_field(field_name, view) do
    field_name
    |> String.split(".", trim: true)
    |> Enum.map(&JSONAPIPlug.recase(&1, :underscore))
    |> parse_sort_components(view, [])
  end

  defp parse_sort_components([field_name], view, components) do
    valid_attributes =
      Enum.map(
        view.attributes(),
        &to_string(View.field_option(&1, :name) || View.field_name(&1))
      )

    unless field_name in valid_attributes do
      raise InvalidQuery, type: view.type(), param: "sort", value: field_name
    end

    [field_name | components]
    |> Enum.reverse()
    |> Enum.join("_")
    |> String.to_existing_atom()
  end

  defp parse_sort_components([field_name | rest], view, components) do
    relationships = view.relationships()

    valid_relationships =
      Enum.map(
        relationships,
        &to_string(View.field_option(&1, :name) || View.field_name(&1))
      )

    unless field_name in valid_relationships do
      raise InvalidQuery, type: view.type(), param: "sort", value: field_name
    end

    related_view =
      Enum.find_value(relationships, fn relationship ->
        String.to_existing_atom(field_name) == View.field_name(relationship) &&
          View.field_option(relationship, :view)
      end)

    parse_sort_components(rest, related_view, [field_name | components])
  end
end
