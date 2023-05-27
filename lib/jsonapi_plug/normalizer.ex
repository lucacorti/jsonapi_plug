defmodule JSONAPIPlug.Normalizer do
  @moduledoc """
  Transforms user data to and from a `JSON:API` Document.

  The default implementation transforms `JSON:API`documents in requests to an ecto
  friendly format and expects `Ecto.Schema` instances when rendering data in responses.
  The data it produces is stored under the `:params` key of the `JSONAPIPlug` struct
  that will be stored in the `Plug.Conn` private assign `:jsonapi_plug`.

  You can customize normalization to convert your application data to and from
  the `JSONAPIPlug.Document` data structure by providing an implementation of
  the `JSONAPIPlug.Normalizer` behaviour.

  You can return an error during parsing by raising `JSONAPIPlug.Exceptions.InvalidDocument` at
  any point in your code.
  """

  alias JSONAPIPlug.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    Resource,
    Resource.Fields,
    Resource.Identity,
    Resource.Links,
    Resource.Meta,
    Resource.Params
  }

  alias Plug.Conn

  @doc "Transforms a JSON:API Document into params"
  @spec denormalize(Document.t(), Resource.data(), Conn.t()) :: Conn.params() | no_return()
  def denormalize(document, resource, conn), do: denormalize_data(document, resource, conn)

  defp denormalize_data(%Document{data: nil}, _resource, _conn), do: %{}

  defp denormalize_data(%Document{data: resource_objects} = document, resource, conn)
       when is_list(resource_objects) do
    Enum.map(resource_objects, &denormalize_resource(document, &1, resource, conn))
  end

  defp denormalize_data(
         %Document{data: %ResourceObject{} = resource_object} = document,
         resource,
         conn
       ) do
    denormalize_resource(document, resource_object, resource, conn)
  end

  defp denormalize_resource(
         document,
         %ResourceObject{} = resource_object,
         resource,
         conn
       ) do
    Params.resource_params(resource)
    |> denormalize_id(resource_object, resource, conn)
    |> denormalize_attributes(resource_object, resource, conn)
    |> denormalize_relationships(resource_object, document, resource, conn)
  end

  defp denormalize_id(
         params,
         %ResourceObject{id: nil},
         resource,
         _conn
       ) do
    if Identity.client_generated_ids?(resource) do
      raise InvalidDocument,
        message: "Resource ID not received in request and API requires Client-Generated IDs",
        reference: "https://jsonapi.org/format/1.0/#crud-creating-client-ids"
    end

    params
  end

  defp denormalize_id(params, %ResourceObject{} = resource_object, resource, _conn),
    do:
      Params.denormalize_attribute(
        resource,
        params,
        to_string(Identity.id_attribute(resource)),
        resource_object.id
      )

  defp denormalize_attributes(
         params,
         %ResourceObject{} = resource_object,
         resource,
         conn
       ) do
    resource
    |> Fields.attributes()
    |> Enum.reduce(params, fn attribute, params ->
      name = Resource.field_name(attribute)
      deserialize = Resource.field_option(attribute, :deserialize)
      key = to_string(Resource.field_option(attribute, :name) || name)

      case Map.fetch(resource_object.attributes, recase_field(resource, name)) do
        {:ok, _value} when deserialize == false ->
          params

        {:ok, value} when is_function(deserialize, 2) ->
          Params.denormalize_attribute(resource, params, key, deserialize.(value, conn))

        {:ok, value} ->
          Params.denormalize_attribute(resource, params, key, value)

        :error ->
          params
      end
    end)
  end

  defp denormalize_relationships(
         params,
         %ResourceObject{relationships: relationships},
         %Document{} = document,
         resource,
         conn
       ) do
    resource
    |> Fields.relationships()
    |> Enum.reduce(params, fn relationship, params ->
      name = Resource.field_name(relationship)
      key = to_string(Resource.field_option(relationship, :name) || name)
      related_resource = Resource.field_option(relationship, :resource)
      related_many = Resource.field_option(relationship, :many)
      related_relationships = Map.get(relationships, to_string(name))

      case {related_many, related_relationships} do
        {_many, nil} ->
          params

        {true, related_relationships} when is_list(related_relationships) ->
          value =
            Enum.map(
              related_relationships,
              &find_related_relationship(document, &1, struct(related_resource), conn)
            )

          Params.denormalize_relationship(resource, params, related_relationships, key, value)

        {_many, related_relationships} when is_list(related_relationships) ->
          raise InvalidDocument,
            message: "List of resources for one-to-one relationship during normalization",
            reference: nil

        {true, _related_relationships} ->
          raise InvalidDocument,
            message: "Single resource for many relationship during normalization",
            reference: nil

        {_many, %RelationshipObject{data: nil}} ->
          Map.put(params, key <> "_id", nil)

        {_many, related_relationship} ->
          value =
            find_related_relationship(
              document,
              related_relationship,
              struct(related_resource),
              conn
            )

          Params.denormalize_relationship(resource, params, related_relationship, key, value)
      end
    end)
  end

  defp find_related_relationship(
         %Document{} = document,
         %RelationshipObject{
           data: %ResourceIdentifierObject{
             id: id,
             type: type
           }
         },
         resource,
         conn
       ) do
    Enum.find_value(document.included || [], fn
      %ResourceObject{id: ^id, type: ^type} = resource_object ->
        denormalize_resource(document, resource_object, resource, conn)

      %ResourceObject{} ->
        nil
    end)
  end

  @doc "Transforms user data into a JSON:API Document"
  @spec normalize(Conn.t(), Resource.data(), Document.links(), Document.meta()) ::
          Document.t() | no_return()
  def normalize(conn, resources, links, meta) do
    %Document{links: links, meta: meta}
    |> normalize_data(conn, resources)
    |> normalize_included(conn, resources)
    |> included_to_list()
  end

  defp normalize_data(document, _conn, nil = _resources),
    do: document

  defp normalize_data(%Document{} = document, conn, resources)
       when is_list(resources),
       do: %{
         document
         | data: Enum.map(resources, &normalize_resource(conn, &1))
       }

  defp normalize_data(%Document{} = document, conn, resource),
    do: %{document | data: normalize_resource(conn, resource)}

  defp normalize_resource(conn, resource) do
    %ResourceObject{}
    |> normalize_id(conn, resource)
    |> normalize_type(conn, resource)
    |> normalize_attributes(conn, resource)
    |> normalize_links(conn, resource)
    |> normalize_meta(conn, resource)
    |> normalize_relationships(conn, resource)
  end

  defp normalize_id(%ResourceObject{} = resource_object, _conn, resource),
    do: %{
      resource_object
      | id: to_string(Params.normalize_attribute(resource, Identity.id_attribute(resource)))
    }

  defp normalize_type(%ResourceObject{} = resource_object, _conn, resource),
    do: %{resource_object | type: Identity.type(resource)}

  defp normalize_attributes(%ResourceObject{} = resource_object, conn, resource) do
    %{
      resource_object
      | attributes:
          Fields.attributes(resource)
          |> requested_fields(resource, conn)
          |> Enum.reduce(%{}, fn attribute, attributes ->
            name = Resource.field_name(attribute)
            key = Resource.field_option(attribute, :name) || Resource.field_name(attribute)

            case Resource.field_option(attribute, :serialize) do
              false ->
                attributes

              serialize when serialize in [true, nil] ->
                value = Params.normalize_attribute(resource, key)

                Map.put(attributes, recase_field(resource, name), value)

              serialize when is_function(serialize, 2) ->
                value = serialize.(resource, conn)

                Map.put(attributes, recase_field(resource, name), value)
            end
          end)
    }
  end

  defp normalize_links(%ResourceObject{} = resource_object, conn, resource),
    do: %{resource_object | links: Links.links(resource, conn)}

  defp normalize_meta(%ResourceObject{} = resource_object, conn, resource),
    do: %{resource_object | meta: Meta.meta(resource, conn)}

  defp normalize_relationships(%ResourceObject{} = resource_object, conn, resource) do
    %{
      resource_object
      | relationships:
          Fields.relationships(resource)
          |> Enum.filter(&relationship_loaded?(Map.get(resource, elem(&1, 0))))
          |> Enum.into(%{}, fn relationship ->
            name = Resource.field_name(relationship)

            key =
              Resource.field_option(relationship, :name) ||
                Resource.field_name(relationship)

            related_resources = Map.get(resource, key)
            related_many = Resource.field_option(relationship, :many)

            case {related_many, related_resources} do
              {false, related_resources} when is_list(related_resources) ->
                raise InvalidDocument,
                  message: "List of resources given to render for one-to-one relationship",
                  reference: nil

              {true, related_resources} when not is_list(related_resources) ->
                raise InvalidDocument,
                  message: "Single resource given to render for many relationship",
                  reference: nil

              {_related_many, related_resources} ->
                {
                  recase_field(resource, name),
                  %RelationshipObject{
                    data: normalize_relationship(related_resources, conn),
                    meta: Meta.meta(resource, conn)
                  }
                }
            end
          end)
    }
  end

  defp normalize_relationship(related_resources, conn) when is_list(related_resources),
    do: Enum.map(related_resources, &normalize_relationship(&1, conn))

  defp normalize_relationship(related_resource, conn) do
    id = Identity.id_attribute(related_resource)

    %ResourceIdentifierObject{
      id: to_string(Params.normalize_attribute(related_resource, id)),
      type: Identity.type(related_resource),
      meta: Meta.meta(related_resource, conn)
    }
  end

  defp normalize_included(document, _conn, nil = _resources),
    do: document

  defp normalize_included(document, conn, resources) when is_list(resources),
    do: Enum.reduce(resources, document, &normalize_included(&2, conn, &1))

  defp normalize_included(
         document,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resource
       ) do
    resource
    |> Fields.relationships()
    |> Enum.filter(&get_in(jsonapi_plug.include, [elem(&1, 0)]))
    |> Enum.reduce(
      document,
      &normalize_resource_included(&2, conn, resource, &1)
    )
  end

  defp normalize_included(document, _conn, _resource), do: document

  defp normalize_resource_included(
         %Document{} = document,
         conn,
         resource,
         relationship
       ) do
    name = Resource.field_name(relationship)
    related_resource = Map.get(resource, name)
    related_loaded? = relationship_loaded?(related_resource)
    related_many = Resource.field_option(relationship, :many)

    included =
      case {related_loaded?, related_many, related_resource} do
        {true, true, related_resource} when is_list(related_resource) ->
          MapSet.union(
            document.included || MapSet.new(),
            MapSet.new(Enum.map(related_resource, &normalize_resource(conn, &1)))
          )

        {true, _related_many, related_resource} when is_list(related_resource) ->
          raise InvalidDocument,
            message: "List of resources given to render for one-to-one relationship",
            reference: nil

        {true, true, _related_resource} ->
          raise InvalidDocument,
            message: "Single resource given to render for many relationship",
            reference: nil

        {true, _related_many, related_resource} ->
          MapSet.put(
            document.included || MapSet.new(),
            normalize_resource(conn, related_resource)
          )

        {false, _related_many, _related_resource} ->
          document.included
      end

    normalize_included(
      %{document | included: included},
      update_in(conn.private.jsonapi_plug.include, & &1[name]),
      related_resource
    )
  end

  defp included_to_list(%Document{included: nil} = document), do: document

  defp included_to_list(%Document{included: included} = document),
    do: %{document | included: MapSet.to_list(included)}

  defp recase_field(resource, field),
    do: Resource.field_recase(field, Fields.case(resource))

  defp relationship_loaded?(nil), do: false
  defp relationship_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: false
  defp relationship_loaded?(_value), do: true

  defp requested_fields(attributes, resource, %Conn{
         private: %{jsonapi_plug: %JSONAPIPlug{fields: fields}}
       })
       when is_map(fields) do
    case fields[Identity.type(resource)] do
      nil ->
        attributes

      fields when is_list(fields) ->
        Enum.filter(attributes, fn attribute -> Resource.field_name(attribute) in fields end)
    end
  end

  defp requested_fields(attributes, _resource, _conn), do: attributes
end
