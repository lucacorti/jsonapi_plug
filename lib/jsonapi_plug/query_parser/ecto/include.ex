defmodule JSONAPIPlug.QueryParser.Ecto.Include do
  @moduledoc """
  JSON:API 'include' query parameter parser implementation for Ecto

  Expects `include` parameter to be in the [JSON:API include](https://jsonapi.org/format/#fetching-includes)
  format and converts them to Ecto `preload` optio to `Ecto.Repo` functions.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, View}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi, nil), do: []

  def parse(%JSONAPIPlug{resource: resource}, include) when is_binary(include) do
    include
    |> String.split(",", trim: true)
    |> Enum.map(fn include ->
      include
      |> JSONAPIPlug.recase(:underscore)
      |> String.split(".", trim: true)
    end)
    |> valid_includes(resource)
  end

  def parse(%JSONAPIPlug{resource: resource}, include) do
    raise InvalidQuery, type: resource.type(), param: "include", value: include
  end

  defp valid_includes(includes, resource) do
    relationships = resource.relationships()
    valid_relationships_includes = Enum.map(relationships, &to_string(View.field_name(&1)))

    Enum.reduce(
      relationships,
      [],
      &process_relationship_include(resource, &1, includes, &2, valid_relationships_includes)
    )
    |> Keyword.merge([], fn _k, a, b -> Keyword.merge(a, b) end)
  end

  defp process_relationship_include(
         resource,
         relationship,
         includes,
         valid_includes,
         valid_relationships_includes
       ) do
    name = View.field_option(relationship, :name) || View.field_name(relationship)
    include_name = to_string(name)

    Enum.reduce(includes, [], fn
      [^include_name], relationship_includes ->
        update_in(
          relationship_includes,
          [name],
          &Keyword.merge(&1 || [], [], fn _k, a, b -> Keyword.merge(a, b) end)
        )

      [^include_name | rest], relationship_includes ->
        case View.field_option(relationship, :resource) do
          nil ->
            relationship_includes

          related_resource ->
            update_in(
              relationship_includes,
              [name],
              &Keyword.merge(&1 || [], valid_includes([rest], related_resource))
            )
        end

      [include_name | _] = path, relationship_includes ->
        if include_name in valid_relationships_includes do
          relationship_includes
        else
          raise InvalidQuery, type: resource.type(), param: "include", value: Enum.join(path, ".")
        end
    end)
    |> Keyword.merge(valid_includes, fn _k, a, b -> Keyword.merge(a, b) end)
  end
end
