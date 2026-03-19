defmodule JSONAPIPlug.QueryParser.Ecto.Include do
  @moduledoc """
  JSON:API `include` query parameter parser implementation for Ecto

  Parses a comma-separated [JSON:API include](https://jsonapi.org/format/#fetching-includes)
  string and converts it into a nested keyword list suitable for use as the `:preload`
  option to `Ecto.Repo` functions.

  For example, the query string:

      ?include=author,bestComments.user.company,bestComments.user.topPosts

  is parsed into:

      [author: [], best_comments: [user: [company: [], top_posts: []]]]

  Relationship names are converted from camelCase to snake_case. Paths that share
  an intermediate relationship node are deep-merged so that all leaf preloads are
  preserved.
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, QueryParser, Resource}

  @behaviour QueryParser

  @impl QueryParser
  def parse(_jsonapi, nil), do: []

  def parse(%JSONAPIPlug{allowed_includes: allowed_includes, resource: resource}, include)
      when is_binary(include) do
    include
    |> String.split(",", trim: true)
    |> Enum.map(fn include ->
      include
      |> JSONAPIPlug.recase(:underscore)
      |> String.split(".", trim: true)
    end)
    |> valid_includes(resource, allowed_includes)
  end

  def parse(%JSONAPIPlug{resource: resource}, include) do
    raise InvalidQuery, type: Resource.type(resource), param: "include", value: include
  end

  defp valid_includes(includes, resource, allowed_includes) do
    relationships = Resource.relationships(resource)
    valid_relationships_includes = Enum.map(relationships, &to_string/1)

    Enum.reduce(
      relationships,
      [],
      &process_relationship_include(
        resource,
        &1,
        includes,
        &2,
        valid_relationships_includes,
        allowed_includes
      )
    )
    |> Keyword.merge([], fn _k, a, b -> Keyword.merge(a, b) end)
  end

  defp process_relationship_include(
         resource,
         relationship,
         includes,
         valid_includes,
         valid_relationships_includes,
         allowed_includes
       ) do
    name = Resource.field_option(resource, relationship, :name) || relationship
    include_name = to_string(name)

    Enum.reduce(includes, [], fn
      [^include_name], relationship_includes ->
        update_in(
          relationship_includes,
          [name],
          &Keyword.merge(&1 || [], [], fn _k, a, b -> Keyword.merge(a, b) end)
        )

      [^include_name | rest], relationship_includes ->
        related_allowed_includes =
          is_list(allowed_includes) &&
            get_in(allowed_includes, [String.to_existing_atom(include_name)])

        case Resource.field_option(resource, relationship, :resource) do
          nil ->
            relationship_includes

          related_resource ->
            update_in(
              relationship_includes,
              [name],
              &deep_merge(
                &1 || [],
                valid_includes([rest], struct(related_resource), related_allowed_includes)
              )
            )
        end

      [include_name | _] = path, relationship_includes ->
        check_relationship_include(
          resource,
          valid_relationships_includes,
          allowed_includes,
          include_name,
          path,
          relationship_includes
        )
    end)
    |> Keyword.merge(valid_includes, fn _k, a, b -> Keyword.merge(a, b) end)
  end

  defp deep_merge(kw1, kw2) do
    Keyword.merge(kw1, kw2, fn _key, v1, v2 ->
      if is_list(v1) and is_list(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end

  def check_relationship_include(
        resource,
        valid_relationships_includes,
        allowed_includes,
        include_name,
        path,
        relationship_includes
      ) do
    name = String.to_existing_atom(include_name)

    if include_name in valid_relationships_includes and
         (not is_list(allowed_includes) or get_in(allowed_includes, [name])) do
      relationship_includes
    else
      raise ArgumentError
    end
  rescue
    ArgumentError ->
      reraise InvalidQuery.exception(
                type: Resource.type(resource),
                param: "include",
                value: Enum.join(path, ".")
              ),
              __STACKTRACE__
  end
end
