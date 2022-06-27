defmodule JSONAPI.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#resource_object-resource-objects
  """

  alias JSONAPI.{
    API,
    Document,
    Document.RelationshipObject,
    Resource,
    Resource.Loadable,
    View
  }

  alias Plug.Conn

  @type value :: String.t() | integer() | float() | [value()] | %{String.t() => value()}

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type(),
          attributes: %{String.t() => value()} | nil,
          relationships: %{String.t() => [RelationshipObject.t()]} | nil,
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
        %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn,
        options
      ),
      do: serialize_resource(view, resources, conn, jsonapi.include, options)

  def serialize(view, resources, conn, options),
    do: serialize_resource(view, resources, conn, [], options)

  defp serialize_resource(view, resources, conn, include, options) when is_list(resources) do
    Enum.map_reduce(resources, [], fn resource, resource_objects ->
      {to_include, resource_object} = serialize_resource(view, resource, conn, include, options)
      {to_include, [resource_object | resource_objects]}
    end)
  end

  defp serialize_resource(view, resource, conn, include, options) do
    %__MODULE__{id: view.id(resource), type: view.type()}
    |> serialize_attributes(view, resource, conn)
    |> serialize_links(view, resource, conn)
    |> serialize_meta(view, resource, conn)
    |> serialize_relationships(view, resource, conn, include, options)
  end

  defp serialize_attributes(%__MODULE__{} = resource_object, view, resource, conn) do
    attributes =
      view
      |> attributes_for_type(conn)
      |> Enum.reduce(%{}, fn field, attributes ->
        value =
          if function_exported?(view, field, 2) do
            apply(view, field, [resource, conn])
          else
            Map.get(resource, field)
          end

        Map.put(attributes, inflect_field(conn, field), value)
      end)

    %__MODULE__{resource_object | attributes: attributes}
  end

  defp inflect_field(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}}, field),
    do: Resource.inflect(field, API.get_config(jsonapi.api, :inflection, :camelize))

  defp inflect_field(_conn, field),
    do: Resource.inflect(field, :camelize)

  defp attributes_for_type(view, %Conn{private: %{jsonapi: %JSONAPI{fields: %{}} = jsonapi}}) do
    view.attributes()
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(jsonapi.fields[view.type()] || view.attributes()))
    |> MapSet.to_list()
  end

  defp attributes_for_type(view, _conn), do: view.attributes()

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
    includes = get_includes(view, include)

    view.relationships()
    |> Enum.filter(&Loadable.loaded?(Map.get(resource, elem(&1, 0))))
    |> Enum.flat_map_reduce(
      resource_object,
      fn
        {relationship_field, relationship_options},
        %__MODULE__{relationships: relationships} = resource_object ->
          relationship = Map.get(resource, relationship_field)
          relationship_type = inflect_field(conn, relationship_field)
          relationship_url = View.url_for_relationship(view, resource, conn, relationship_type)
          relationship_view = Keyword.fetch!(relationship_options, :view)

          relationship_object =
            RelationshipObject.serialize(
              relationship_view,
              relationship,
              conn,
              relationship_url
            )

          relationships = Map.put(relationships, relationship_type, relationship_object)
          resource_object = %__MODULE__{resource_object | relationships: relationships}

          if Keyword.get(includes, relationship_field) do
            {included_relationships, serialized_relationship} =
              serialize_resource(
                relationship_view,
                relationship,
                conn,
                get_relationship_includes(include, relationship_field),
                options
              )

            {[serialized_relationship | included_relationships], resource_object}
          else
            {[], resource_object}
          end
      end
    )
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

  defp get_includes(view, query_includes) do
    relationships = view.relationships()

    query_includes
    |> Enum.flat_map(fn
      {include, _} -> Keyword.take(relationships, [include])
      include -> Keyword.take(relationships, [include])
    end)
    |> Enum.uniq()
  end

  @spec deserialize(View.t(), Document.payload(), Document.included()) :: %{String.t() => term()}
  def deserialize(view, data, included) do
    %{}
    |> deserialize_attributes(view, data)
    |> deserialize_relationships(view, data, included)
    |> deserialize_id(view, data)
  end

  defp deserialize_id(resource, view, %{"id" => id}),
    do: Map.put(resource, to_string(view.id_attribute()), id)

  defp deserialize_id(resource, _view, _data), do: resource

  defp deserialize_attributes(resource, view, %{"attributes" => attributes})
       when is_map(attributes) do
    view.attributes()
    |> Enum.reduce(resource, fn attribute, resource ->
      {from, to} = map_attribute!(attribute)

      case Map.fetch(attributes, from) do
        {:ok, value} ->
          Map.put(resource, to, value)

        :error ->
          resource
      end
    end)
  end

  defp deserialize_attributes(resource, _view, _data), do: resource

  defp map_attribute!(attribute) when is_atom(attribute),
    do: {to_string(attribute), to_string(attribute)}

  defp map_attribute!({attribute, options}) when is_atom(attribute),
    do: {to_string(attribute), to_string(Keyword.get(options, :to, attribute))}

  defp map_attribute!(attribute),
    do: raise("Invalid attribute specification #{inspect(attribute)}")

  defp deserialize_relationships(
         resource,
         view,
         %{"relationships" => relationships} = _data,
         included
       )
       when is_map(relationships) do
    view.relationships()
    |> Enum.reduce(resource, fn {relationship, options}, resource ->
      many = Keyword.get(options, :many, false)
      {from, to} = map_attribute!(relationship)

      case Map.fetch(relationships, from) do
        {:ok, relationships} when many == true ->
          Map.put(
            resource,
            to,
            Enum.map(relationships, &deserialize_relationship(view, &1, included))
          )

        {:ok, relationship} ->
          Map.put(
            resource,
            to,
            deserialize_relationship(view, relationship, included)
          )

        :error ->
          resource
      end
    end)
  end

  defp deserialize_relationships(resource, _view, _data, _included), do: resource

  defp deserialize_relationship(
         view,
         %{"data" => %{"id" => id, "type" => type}},
         included
       ) do
    Enum.reduce_while(included, %{"id" => id}, fn
      %{"type" => ^type, "id" => ^id} = included_resource, result ->
        case View.for_related_type(view, type) do
          nil -> {:halt, result}
          related_view -> {:halt, deserialize(related_view, included_resource, included)}
        end

      _included_resource, result ->
        {:cont, result}
    end)
  end
end
