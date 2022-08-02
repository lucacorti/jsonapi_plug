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
      view.attributes()
      |> requested_fields(view, conn)
      |> Enum.reduce(%{}, fn attribute, attributes ->
        name = View.field_name(attribute)

        case View.field_option(attribute, :serialize, true) do
          false ->
            attributes

          true ->
            value = Map.get(resource, name)

            Map.put(attributes, recase_field(conn, name), value)

          serialize when is_function(serialize, 2) ->
            value = serialize.(resource, conn)

            Map.put(attributes, recase_field(conn, name), value)
        end
      end)

    %__MODULE__{resource_object | attributes: attributes}
  end

  defp requested_fields(attributes, view, %Conn{
         private: %{jsonapi: %JSONAPI{fields: fields}}
       })
       when is_map(fields) do
    case fields[view.type()] do
      nil ->
        attributes

      fields when is_list(fields) ->
        Enum.filter(attributes, fn attribute -> View.field_name(attribute) in fields end)
    end
  end

  defp requested_fields(attributes, _view, _conn), do: attributes

  defp recase_field(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}}, field),
    do: Resource.recase(field, API.get_config(jsonapi.api, :case, :camelize))

  defp recase_field(_conn, field),
    do: Resource.recase(field, :camelize)

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
      fn relationship, %__MODULE__{relationships: relationships} = resource_object ->
        name = View.field_name(relationship)
        data = Map.get(resource, name)
        type = recase_field(conn, name)
        url = View.url_for_relationship(view, resource, conn, type)
        view = View.field_option(relationship, :view, nil)

        relationships =
          Map.put(
            relationships,
            type,
            RelationshipObject.serialize(view, data, conn, url)
          )

        resource_object = %__MODULE__{resource_object | relationships: relationships}

        if Keyword.get(includes, name) do
          {included_relationships, serialized_relationship} =
            serialize_resource(
              view,
              data,
              conn,
              get_relationship_includes(include, name),
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

  @spec deserialize(View.t(), Conn.t(), Document.payload(), Document.included()) ::
          %{String.t() => term()}
  def deserialize(view, conn, data, included) do
    %{}
    |> deserialize_attributes(view, conn, data)
    |> deserialize_relationships(view, conn, data, included)
    |> deserialize_id(view, data)
  end

  defp deserialize_id(resource, view, %{"id" => id}),
    do: Map.put(resource, to_string(view.id_attribute()), id)

  defp deserialize_id(resource, _view, _data), do: resource

  defp deserialize_attributes(resource, view, conn, %{"attributes" => attributes})
       when is_map(attributes) do
    view.attributes()
    |> Enum.reduce(resource, fn attribute, resource ->
      case View.field_option(attribute, :deserialize, true) do
        false ->
          resource

        true ->
          name = View.field_name(attribute)

          Map.put(
            resource,
            to_string(View.field_option(attribute, :name, name)),
            Map.get(attributes, recase_field(conn, to_string(name)))
          )

        deserialize when is_function(deserialize, 2) ->
          name = View.field_name(attribute)

          Map.put(
            resource,
            to_string(View.field_option(attribute, :name, name)),
            deserialize.(Map.get(attributes, recase_field(conn, to_string(name))), conn)
          )
      end
    end)
  end

  defp deserialize_attributes(resource, _view, _conn, _data), do: resource

  defp deserialize_relationships(
         resource,
         view,
         conn,
         %{"relationships" => relationships},
         included
       )
       when is_map(relationships) do
    view.relationships()
    |> Enum.reduce(resource, fn relationship, resource ->
      many = View.field_option(relationship, :many, false)
      name = View.field_name(relationship)

      case Map.fetch(relationships, recase_field(conn, to_string(name))) do
        {:ok, data} when many == true ->
          Map.put(
            resource,
            to_string(View.field_option(relationship, :name, name)),
            Enum.map(data, &deserialize_relationship_data(view, conn, &1, included))
          )

        {:ok, data} ->
          Map.put(
            resource,
            to_string(View.field_option(relationship, :name, name)),
            deserialize_relationship_data(view, conn, data, included)
          )

        :error ->
          resource
      end
    end)
  end

  defp deserialize_relationships(resource, _view, _conn, _data, _included), do: resource

  defp deserialize_relationship_data(
         view,
         conn,
         %{"data" => %{"id" => id, "type" => type}},
         included
       ) do
    Enum.reduce_while(included, %{"id" => id}, fn
      %{"type" => ^type, "id" => ^id} = included_resource, result ->
        case View.for_related_type(view, type) do
          nil -> {:halt, result}
          related_view -> {:halt, deserialize(related_view, conn, included_resource, included)}
        end

      _included_resource, result ->
        {:cont, result}
    end)
  end
end
