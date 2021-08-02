defmodule JSONAPI.Document.Resource do
  @moduledoc """
  JSONAPI Resource
  """
  alias JSONAPI.Document
  alias JSONAPI.Document.Resource.Relationship
  alias JSONAPI.{Resource, Utils, View}
  alias Plug.Conn

  @type attribute :: String.t()

  @type value :: String.t() | integer() | float() | [value()] | %{attribute() => value()}

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type(),
          attributes: %{String.t() => attribute() | %{String.t() => value()}},
          relationships: %{String.t() => [Relationship.t()]},
          links: Document.links()
        }

  @derive Jason.Encoder
  defstruct id: nil, type: nil, attributes: nil, relationships: %{}, links: nil, meta: nil

  @spec serialize(
          View.t(),
          JSONAPI.Resource.t() | [JSONAPI.Resource.t()] | nil,
          Conn.t() | nil,
          [attribute()],
          View.options()
        ) :: {[t()], t() | [t()]}
  def serialize(_view, nil = _resource, _conn, _includes, _options), do: {[], nil}

  def serialize(view, resources, conn, includes, options) when is_list(resources) do
    Enum.map_reduce(resources, [], fn resource, acc ->
      {to_include, serialized_data} = serialize(view, resource, conn, includes, options)

      {to_include, acc ++ [serialized_data]}
    end)
  end

  def serialize(view, resource, conn, query_includes, options) do
    valid_includes = get_includes(view, query_includes)

    %__MODULE__{
      id: view.id(resource),
      type: view.type(),
      attributes: transform_fields(view.attributes(resource, conn)),
      relationships: %{}
    }
    |> add_links(resource, view, conn, nil, options)
    |> add_meta(view.meta(resource, conn))
    |> add_relationships(conn, {view, resource, query_includes, valid_includes}, options)
  end

  defp add_links(%__MODULE__{} = document, resource, view, conn, _page, _options) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: view.url_for(resource, conn)})

    %__MODULE__{document | links: links}
  end

  defp add_meta(%__MODULE__{} = document, meta) when is_map(meta),
    do: %__MODULE__{document | meta: meta}

  defp add_meta(document, _meta), do: document

  defp add_relationships(document, conn, {view, resource, _, _} = view_info, options) do
    view.relationships()
    |> Enum.filter(&assoc_loaded?(Map.get(resource, elem(&1, 0))))
    |> Enum.map_reduce(document, &build_relationships(conn, view_info, &1, &2, options))
  end

  defp build_relationships(
         conn,
         {view, resource, query_includes, valid_includes},
         {key, include_view},
         %__MODULE__{relationships: relationships} = document,
         options
       ) do
    rel_view =
      case include_view do
        {view, :include} -> view
        view -> view
      end

    rel_data = Map.get(resource, key)

    # Build the relationship url
    rel_key = transform_fields(key)
    rel_url = View.url_for_relationship(view, resource, rel_key, conn)

    # Build the relationship
    relationship = Relationship.serialize(rel_view, rel_data, rel_url, conn)
    relationships = Map.put(relationships, rel_key, relationship)

    resource = %__MODULE__{document | relationships: relationships}

    valid_include_view = include_view(valid_includes, key)

    if {rel_view, :include} == valid_include_view && data_loaded?(rel_data) do
      rel_query_includes =
        if is_list(query_includes) do
          query_includes
          |> Enum.reduce([], fn
            {^key, value}, acc -> acc ++ [value]
            _, acc -> acc
          end)
          |> List.flatten()
        else
          []
        end

      {included_relationships, serialized_relationship} =
        serialize(rel_view, rel_data, conn, rel_query_includes, options)

      {included_relationships ++ [serialized_relationship], resource}
    else
      {nil, resource}
    end
  end

  defp data_loaded?(rel_data) do
    assoc_loaded?(rel_data) && (is_map(rel_data) || is_list(rel_data))
  end

  defp assoc_loaded?(nil), do: false
  defp assoc_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: false
  defp assoc_loaded?(_association), do: true

  defp get_includes(view, query_includes) do
    includes = get_default_includes(view) ++ get_query_includes(view, query_includes)

    Enum.uniq(includes)
  end

  defp get_default_includes(view) do
    rels = view.relationships()

    Enum.filter(rels, fn
      {_k, {_v, :include}} -> true
      _ -> false
    end)
  end

  defp get_query_includes(view, query_includes) do
    rels = view.relationships()

    query_includes
    |> Enum.map(fn
      {include, _} -> Keyword.take(rels, [include])
      include -> Keyword.take(rels, [include])
    end)
    |> List.flatten()
  end

  defp generate_view_tuple({view, :include}), do: {view, :include}
  defp generate_view_tuple(view) when is_atom(view), do: {view, :include}

  defp include_view(valid_includes, key) when is_list(valid_includes) do
    valid_includes
    |> Keyword.get(key)
    |> generate_view_tuple
  end

  defp transform_fields(fields) do
    case Application.get_env(:jsonapi, :field_transformation) do
      :camelize -> Utils.String.expand_fields(fields, &Utils.String.camelize/1)
      :dasherize -> Utils.String.expand_fields(fields, &Utils.String.dasherize/1)
      _ -> fields
    end
  end
end
