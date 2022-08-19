defmodule JSONAPI.Plug.Request.Include do
  @moduledoc """
  Plug for parsing the 'include' JSON:API query parameter
  """

  alias JSONAPI.{Exceptions.InvalidQuery, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(
        %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, query_params: query_params} = conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | include: parse_include(jsonapi, query_params["include"])}
    )
  end

  defp parse_include(%JSONAPI{include: include}, nil), do: include

  defp parse_include(%JSONAPI{view: view}, include) when is_binary(include) do
    include
    |> String.split(",", trim: true)
    |> Enum.map(fn include ->
      include
      |> JSONAPI.recase(:underscore)
      |> String.split(".", trim: true)
    end)
    |> valid_includes(view)
  end

  defp parse_include(%JSONAPI{view: view}, include) do
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
