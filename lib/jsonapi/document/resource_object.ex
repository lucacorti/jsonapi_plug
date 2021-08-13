defmodule JSONAPI.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#document-resource-objects
  """

  alias JSONAPI.{Config, Document, Document.RelationshipObject, Resource, Utils, View}
  alias Plug.Conn

  @type attribute :: atom()

  @type value :: String.t() | integer() | float() | [value()] | %{attribute() => value()}

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type(),
          attributes: %{attribute() => value()} | nil,
          relationships: %{attribute() => [RelationshipObject.t()]} | nil,
          links: Document.links() | nil
        }

  defstruct id: nil, type: nil, attributes: nil, relationships: %{}, links: nil, meta: nil

  @spec serialize(
          View.t(),
          View.data() | nil,
          Conn.t() | nil,
          View.options()
        ) :: {[t()], t() | [t()]}

  def serialize(
        view,
        resources,
        %Conn{assigns: %{jsonapi_query: %Config{} = config}} = conn,
        options
      ),
      do: do_serialize(view, resources, conn, config.include, options)

  def serialize(view, resources, conn, options),
    do: do_serialize(view, resources, conn, [], options)

  def do_serialize(_view, nil = _resources, _conn, _includes, _options) do
    {[], nil}
  end

  def do_serialize(view, resources, conn, includes, options) when is_list(resources) do
    Enum.map_reduce(resources, [], fn resource, acc ->
      {to_include, serialized_data} = do_serialize(view, resource, conn, includes, options)

      {to_include, acc ++ [serialized_data]}
    end)
  end

  def do_serialize(view, resource, conn, query_includes, options) do
    valid_includes = get_includes(view, query_includes)

    attributes =
      view
      |> View.attributes(resource, conn)
      |> transform_fields()

    %__MODULE__{
      id: view.id(resource),
      type: view.type(),
      attributes: attributes
    }
    |> serialize_links(resource, view, conn, nil, options)
    |> serialize_meta(view.meta(resource, conn))
    |> serialize_relationships(conn, {view, resource, query_includes, valid_includes}, options)
  end

  defp serialize_links(%__MODULE__{} = document, resource, view, conn, _page, _options) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: view.url_for(resource, conn)})

    %__MODULE__{document | links: links}
  end

  defp serialize_meta(%__MODULE__{} = document, meta) when is_map(meta),
    do: %__MODULE__{document | meta: meta}

  defp serialize_meta(document, _meta), do: document

  defp serialize_relationships(document, conn, {view, resource, _, _} = view_info, options) do
    view.relationships()
    |> Enum.filter(&data_loaded?(Map.get(resource, elem(&1, 0))))
    |> Enum.map_reduce(document, &build_relationships(conn, view_info, &1, &2, options))
  end

  defp build_relationships(
         conn,
         {view, resource, query_includes, valid_includes},
         {key, relationship_view},
         %__MODULE__{relationships: relationships} = document,
         options
       ) do
    relationship_data = Map.get(resource, key)
    relationship_type = transform_fields(key)
    relationship_url = View.url_for_relationship(view, resource, conn, relationship_type)

    relationship =
      RelationshipObject.serialize(relationship_view, relationship_data, conn, relationship_url)

    relationships = Map.put(relationships, relationship_type, relationship)
    resource = %__MODULE__{document | relationships: relationships}

    if Keyword.get(valid_includes, key) && data_loaded?(relationship_data) do
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
        do_serialize(relationship_view, relationship_data, conn, rel_query_includes, options)

      {included_relationships ++ [serialized_relationship], resource}
    else
      {nil, resource}
    end
  end

  defp data_loaded?(nil), do: false
  defp data_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: false
  defp data_loaded?(association) when is_map(association) or is_list(association), do: true

  defp get_includes(view, query_includes) do
    relationships = view.relationships()

    query_includes
    |> Enum.map(fn
      {include, _} -> Keyword.take(relationships, [include])
      include -> Keyword.take(relationships, [include])
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp transform_fields(fields) do
    case Application.get_env(:jsonapi, :field_transformation) do
      :camelize -> Utils.String.expand_fields(fields, &Utils.String.camelize/1)
      :dasherize -> Utils.String.expand_fields(fields, &Utils.String.dasherize/1)
      _ -> fields
    end
  end

  @spec deserialize(View.t(), Document.payload()) :: t()
  def deserialize(_view, _payload) do
    %__MODULE__{id: "0", type: "a"}
  end
end
