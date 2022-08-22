defmodule JSONAPIPlug.QueryParser.Ecto.Include do
  @moduledoc """
  JSON:API 'include' query parameter parser implementation for Ecto

  Expects `include` parameter to be in the [JSON:API include](https://jsonapi.org/format/#fetching-includes)
  format and converts them to Ecto `preload` format for ease of use with `Ecto.Repo` functions.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, View}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi, nil), do: []

  def parse(%JSONAPIPlug{view: view}, include) when is_binary(include) do
    include
    |> String.split(",", trim: true)
    |> Enum.map(fn include ->
      include
      |> JSONAPIPlug.recase(:underscore)
      |> String.split(".", trim: true)
    end)
    |> valid_includes(view)
  end

  def parse(%JSONAPIPlug{view: view}, include) do
    raise InvalidQuery, type: view.type(), param: :include, value: include
  end

  defp valid_includes(includes, view) do
    relationships = view.relationships()
    valid_relationships_includes = Enum.map(relationships, &to_string(View.field_name(&1)))

    Enum.reduce(
      relationships,
      [],
      &process_relationship_include(view, &1, includes, &2, valid_relationships_includes)
    )
    |> Keyword.merge([], fn _k, a, b -> Keyword.merge(a, b) end)
  end

  defp process_relationship_include(
         view,
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
        case View.field_option(relationship, :view) do
          nil ->
            relationship_includes

          related_view ->
            update_in(
              relationship_includes,
              [name],
              &Keyword.merge(&1 || [], valid_includes([rest], related_view))
            )
        end

      [include_name | _] = path, relationship_includes ->
        if include_name in valid_relationships_includes do
          relationship_includes
        else
          raise InvalidQuery, type: view.type(), param: :include, value: Enum.join(path, ".")
        end
    end)
    |> Keyword.merge(valid_includes, fn _k, a, b -> Keyword.merge(a, b) end)
  end
end
