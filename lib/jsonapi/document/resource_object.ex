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
    Resource.Field,
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
        %Conn{assigns: %{jsonapi: %JSONAPI{include: include}}} = conn,
        options
      ),
      do: do_serialize(view, resources, conn, include, options)

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
      |> requested_attributes_for_type(conn)
      |> net_attributes_for_type(view.attributes())
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

  defp inflect_field(%Conn{assigns: %{jsonapi: %JSONAPI{api: api}}}, field),
    do: Field.inflect(field, API.get_config(api, :inflection, :camelize))

  defp inflect_field(_conn, field),
    do: Field.inflect(field, :camelize)

  defp requested_attributes_for_type(view, %Conn{
         assigns: %{jsonapi: %JSONAPI{fields: fields}}
       }),
       do: fields[view.type()]

  defp requested_attributes_for_type(_view, _conn), do: nil

  defp net_attributes_for_type(requested_fields, fields) when requested_fields in [nil, %{}],
    do: fields

  defp net_attributes_for_type(requested_fields, fields) do
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
    includes = get_includes(view, include)

    view.relationships()
    |> Enum.filter(&Loadable.loaded?(Map.get(resource, elem(&1, 0))))
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
         {relationship_field, relationship_opts},
         options
       ) do
    relationship = Map.get(resource, relationship_field)
    relationship_type = inflect_field(conn, relationship_field)
    relationship_url = View.url_for_relationship(view, resource, conn, relationship_type)
    relationship_view = Keyword.fetch!(relationship_opts, :view)

    relationship_object =
      RelationshipObject.serialize(
        relationship_view,
        relationship,
        conn,
        relationship_url
      )

    relationships = Map.put(relationships, relationship_type, relationship_object)
    resource_object = %__MODULE__{resource_object | relationships: relationships}

    if Keyword.get(valid_includes, relationship_field) && Loadable.loaded?(relationship) do
      {included_relationships, serialized_relationship} =
        do_serialize(
          relationship_view,
          relationship,
          conn,
          get_relationship_includes(include, relationship_field),
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

  @spec deserialize(View.t(), Document.payload(), [Resource.t()]) :: Resource.t()
  def deserialize(view, %{"id" => id} = data, included) do
    view.resource()
    |> deserialize_attributes(view, data)
    |> deserialize_relationships(view, data, included)
    |> struct([{view.id_attribute(), id}])
  end

  defp deserialize_attributes(resource, view, %{"attributes" => attributes})
       when is_map(attributes) do
    attrs =
      view.attributes()
      |> Enum.map(fn attribute ->
        {from, to} = map_attribute!(attribute)

        case Map.fetch(attributes, to_string(from)) do
          {:ok, value} ->
            {to, value}

          :error ->
            {to, %Field.NotLoaded{field: from}}
        end
      end)

    struct(resource, attrs)
  end

  defp deserialize_attributes(resource, _view, _data), do: resource

  defp map_attribute!(attribute) when is_atom(attribute), do: {attribute, attribute}
  defp map_attribute!({attribute, options}), do: {attribute, Keyword.get(options, :to, attribute)}

  defp map_attribute!(attribute),
    do: raise("Invalid attribute specification #{inspect(attribute)}")

  defp deserialize_relationships(resource, view, %{"relationships" => relationships}, included)
       when is_map(relationships) do
    attrs =
      view.relationships()
      |> Enum.map(fn {from, options} ->
        many = Keyword.get(options, :many, false)
        to = Keyword.get(options, :to, from)

        case Map.fetch(relationships, to_string(from)) do
          {:ok, relationships} when many == true ->
            {to, Enum.map(relationships, &deserialize_relationship(view, from, &1, included))}

          {:ok, relationship} ->
            {to, deserialize_relationship(view, from, relationship, included)}

          :error ->
            {to, %Field.NotLoaded{field: from}}
        end
      end)

    struct(resource, attrs)
  end

  defp deserialize_relationships(resource, _view, _data, _included), do: resource

  defp deserialize_relationship(
         view,
         relationship,
         %{"data" => %{"id" => id, "type" => type}},
         included
       ) do
    {
      relationship,
      Enum.find(
        included,
        %Field.NotLoaded{field: relationship, id: id, type: type},
        fn resource ->
          type == view.type() && id == view.id(resource)
        end
      )
    }
  end
end
