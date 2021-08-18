defmodule JSONAPI.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#resource_object-resource-objects
  """

  alias JSONAPI.{Config, Document, Document.RelationshipObject, Resource, View}
  alias Plug.Conn

  @type field :: atom()

  @type value :: String.t() | integer() | float() | [value()] | %{field() => value()}

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type(),
          attributes: %{field() => value()} | nil,
          relationships: %{field() => [RelationshipObject.t()]} | nil,
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

  def do_serialize(view, resources, conn, include, options) when is_list(resources) do
    Enum.map_reduce(resources, [], fn resource, resource_objects ->
      {to_include, resource_object} = do_serialize(view, resource, conn, include, options)
      {to_include, [resource_object | resource_objects]}
    end)
  end

  def do_serialize(view, resource, conn, include, options) do
    %__MODULE__{id: view.id(resource), type: view.type()}
    |> serialize_attributes(view, resource, conn)
    |> serialize_links(view, resource, conn)
    |> serialize_meta(view, resource, conn)
    |> serialize_relationships(view, resource, conn, include, options)
  end

  defp serialize_attributes(%__MODULE__{} = resource_object, view, resource, conn) do
    attributes =
      view
      |> requested_fields_for_type(conn)
      |> net_fields_for_type(view.attributes(resource))
      |> Enum.reduce(%{}, fn field, attributes ->
        value =
          if function_exported?(view, field, 2) do
            apply(view, field, [resource, conn])
          else
            Map.get(resource, field)
          end

        Map.put(attributes, field, value)
      end)
      |> JSONAPI.transform_fields()

    %__MODULE__{resource_object | attributes: attributes}
  end

  defp requested_fields_for_type(view, %Conn{assigns: %{jsonapi_query: %Config{fields: fields}}}),
    do: fields[view.type()]

  defp requested_fields_for_type(_view, _conn), do: nil

  defp net_fields_for_type(requested_fields, fields) when requested_fields in [nil, %{}],
    do: fields

  defp net_fields_for_type(requested_fields, fields) do
    fields
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(requested_fields))
    |> MapSet.to_list()
  end

  defp serialize_links(%__MODULE__{} = resource_object, view, resource, conn) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: View.url_for(view, resource, conn)})

    %__MODULE__{resource_object | links: links}
  end

  defp serialize_meta(%__MODULE__{} = resource_object, view, resource, conn) do
    case view.meta(resource, conn) do
      %{} = meta -> %__MODULE__{resource_object | meta: meta}
      _ -> resource_object
    end
  end

  defp serialize_relationships(resource_object, view, resource, conn, include, options) do
    includes = get_includes(view, resource, include)

    view.relationships(resource)
    |> Enum.filter(&Resource.loaded?(Map.get(resource, elem(&1, 0))))
    |> Enum.map_reduce(
      resource_object,
      &build_relationships(
        &2,
        view,
        resource,
        conn,
        {include, includes},
        &1,
        options
      )
    )
  end

  defp build_relationships(
         %__MODULE__{relationships: relationships} = resource_object,
         view,
         resource,
         conn,
         {include, valid_includes},
         {relationship_name, relationship_view},
         options
       ) do
    relationship = Map.get(resource, relationship_name)
    relationship_type = JSONAPI.transform_fields(relationship_name)
    relationship_url = View.url_for_relationship(view, resource, conn, relationship_type)

    relationship_object =
      RelationshipObject.serialize(
        relationship_view,
        relationship,
        conn,
        relationship_url
      )

    relationships = Map.put(relationships, relationship_type, relationship_object)
    resource_object = %__MODULE__{resource_object | relationships: relationships}

    if Keyword.get(valid_includes, relationship_name) && Resource.loaded?(relationship) do
      {included_relationships, serialized_relationship} =
        do_serialize(
          relationship_view,
          relationship,
          conn,
          get_relationship_includes(include, relationship_name),
          options
        )

      {[serialized_relationship | included_relationships], resource_object}
    else
      {nil, resource_object}
    end
  end

  defp get_relationship_includes(include, relationship_name) when is_list(include) do
    include
    |> Enum.flat_map(fn
      {^relationship_name, value} -> [value]
      _ -> []
    end)
    |> List.flatten()
  end

  defp get_relationship_includes(_include, _key), do: []

  defp get_includes(view, resource, query_includes) do
    relationships = view.relationships(resource)

    query_includes
    |> Enum.map(fn
      {include, _} -> Keyword.take(relationships, [include])
      include -> Keyword.take(relationships, [include])
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec deserialize(View.t(), Document.payload()) :: {:ok, t()} | {:error, :invalid}
  def deserialize(_view, _payload) do
    {:ok, %__MODULE__{id: "0", type: "a"}}
  end
end
