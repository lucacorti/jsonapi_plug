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
      |> Enum.reduce(%{}, &serialize_attribute(resource, conn, &1, &2))

    %__MODULE__{resource_object | attributes: attributes}
  end

  defp serialize_attribute(resource, conn, attribute, data) do
    name = View.field_name(attribute)

    case View.field_option(attribute, :serialize, true) do
      false ->
        data

      true ->
        value = Map.get(resource, name)

        Map.put(data, recase_field(conn, name), value)

      serialize when is_function(serialize, 2) ->
        value = serialize.(resource, conn)

        Map.put(data, recase_field(conn, name), value)
    end
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
    do: JSONAPI.recase(field, API.get_config(jsonapi.api, :case, :camelize))

  defp recase_field(_conn, field),
    do: JSONAPI.recase(field, :camelize)

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
    |> Enum.filter(&Resource.loaded?(Map.get(resource, elem(&1, 0))))
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

  defp get_relationship_includes(_include, _relationship_name), do: []

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

  defp deserialize_attributes(resource, view, conn, %{"attributes" => data})
       when is_map(data) do
    Enum.reduce(view.attributes(), resource, &deserialize_attribute(&2, conn, data, &1))
  end

  defp deserialize_attributes(resource, _view, _conn, _data), do: resource

  defp deserialize_attribute(resource, conn, data, attribute) do
    case View.field_option(attribute, :deserialize, true) do
      false ->
        resource

      deserialize ->
        name = View.field_name(attribute)

        case Map.fetch(data, recase_field(conn, to_string(name))) do
          {:ok, value} ->
            Map.put(
              resource,
              to_string(View.field_option(attribute, :name, name)),
              deserialize_attribute_value(deserialize, conn, value)
            )

          :error ->
            resource
        end
    end
  end

  defp deserialize_attribute_value(deserialize, conn, value) when is_function(deserialize, 2),
    do: deserialize.(value, conn)

  defp deserialize_attribute_value(_deserailze, _conn, value), do: value

  defp deserialize_relationships(
         resource,
         view,
         conn,
         %{"relationships" => data},
         included
       )
       when is_map(data) do
    Enum.reduce(
      view.relationships(),
      resource,
      &deserialize_relationship(&2, view, conn, data, included, &1)
    )
  end

  defp deserialize_relationships(resource, _view, _conn, _data, _included), do: resource

  defp deserialize_relationship(resource, view, conn, data, included, relationship) do
    name = View.field_name(relationship)

    case Map.fetch(data, recase_field(conn, to_string(name))) do
      {:ok, data} ->
        key = to_string(View.field_option(relationship, :name, name))
        many = View.field_option(relationship, :many, false)

        resource
        |> deserialize_relationship_id(key, data, many)
        |> Map.put(key, deserialize_related_from_included(view, conn, data, included, many))

      :error ->
        resource
    end
  end

  defp deserialize_relationship_id(resource, key, data, false = _many),
    do: Map.put(resource, Enum.join([key, "id"], "_"), data["data"]["id"])

  defp deserialize_relationship_id(resource, _key, _data, true = _many), do: resource

  defp deserialize_related_from_included(
         view,
         conn,
         %{"data" => %{"id" => id, "type" => type}},
         included,
         false = _many
       ) do
    Enum.find_value(included, fn
      %{"type" => ^type, "id" => ^id} = included_resource ->
        case View.for_related_type(view, type) do
          nil -> nil
          related_view -> deserialize(related_view, conn, included_resource, included)
        end

      _included_resource ->
        nil
    end)
  end

  defp deserialize_related_from_included(
         view,
         conn,
         data,
         included,
         true = _many
       )
       when is_list(data) do
    Enum.reduce(data, [], fn relationship_data, resources ->
      case deserialize_related_from_included(view, conn, relationship_data, included, false) do
        nil -> resources
        resource -> [resource | resources]
      end
    end)
    |> Enum.reverse()
  end
end
