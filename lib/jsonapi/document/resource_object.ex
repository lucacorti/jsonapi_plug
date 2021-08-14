defmodule JSONAPI.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#resource_object-resource-objects
  """

  alias JSONAPI.{Config, Document, Document.RelationshipObject, Resource, Utils, View}
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

  def do_serialize(_view, nil = _resources, _conn, _includes, _options) do
    {[], nil}
  end

  def do_serialize(view, resources, conn, include, options) when is_list(resources) do
    Enum.map_reduce(resources, [], fn resource, data ->
      {to_include, serialized_data} = do_serialize(view, resource, conn, include, options)

      {to_include, [serialized_data | data]}
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
      |> View.attributes(resource, conn)
      |> transform_fields()

    %__MODULE__{resource_object | attributes: attributes}
  end

  defp serialize_links(%__MODULE__{} = resource_object, view, resource, conn) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: view.url_for(resource, conn)})

    %__MODULE__{resource_object | links: links}
  end

  defp serialize_meta(%__MODULE__{} = resource_object, view, resource, conn) do
    case view.meta(resource, conn) do
      %{} = meta -> %__MODULE__{resource_object | meta: meta}
      _ -> resource_object
    end
  end

  defp serialize_relationships(resource_object, view, resource, conn, include, options) do
    view.relationships()
    |> Enum.filter(&data_loaded?(Map.get(resource, elem(&1, 0))))
    |> Enum.map_reduce(
      resource_object,
      &build_relationships(&2, view, resource, conn, {include, get_includes(view, include)}, &1, options)
    )
  end

  defp build_relationships(
         %__MODULE__{relationships: relationships} = resource_object,
         view,
         resource,
         conn,
         {include, valid_includes},
         {key, relationship_view},
         options
       ) do
    relationship_data = Map.get(resource, key)
    relationship_type = transform_fields(key)
    relationship_url = View.url_for_relationship(view, resource, conn, relationship_type)

    relationship =
      RelationshipObject.serialize(relationship_view, relationship_data, conn, relationship_url)

    relationships = Map.put(relationships, relationship_type, relationship)
    resource = %__MODULE__{resource_object | relationships: relationships}

    if Keyword.get(valid_includes, key) && data_loaded?(relationship_data) do
      relationship_includes =
        if is_list(include) do
          include
          |> Enum.reduce([], fn
            {^key, value}, acc -> [value | acc]
            _, acc -> acc
          end)
          |> Enum.reverse()
          |> List.flatten()
        else
          []
        end

      {included_relationships, serialized_relationship} =
        do_serialize(relationship_view, relationship_data, conn, relationship_includes, options)

      {[serialized_relationship | included_relationships], resource}
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
