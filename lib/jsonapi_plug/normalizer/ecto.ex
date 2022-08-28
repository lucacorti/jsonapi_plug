defmodule JSONAPIPlug.Normalizer.Ecto do
  @moduledoc """
  JSON:API parameters normalizer implementation for Ecto

  Normalizer implementation translating `JSON:API` documents to and from an Ecto friendly
  format in conn params. Deserialization produces attributes and relationships in a way
  that directly translates to attributes that can be passed to an `Ecto.Changeset` for
  validation and later to `Ecto.Repo` for database operations.
  """

  alias JSONAPIPlug.{
    API,
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    Normalizer,
    Pagination,
    View
  }

  alias Plug.Conn

  @behaviour Normalizer

  @impl Normalizer
  def denormalize(%Document{data: nil}, _view, _conn), do: %{}

  def denormalize(%Document{data: resource_objects} = document, view, conn)
      when is_list(resource_objects),
      do: Enum.map(resource_objects, &denormalize_resource(document, &1, view, conn))

  def denormalize(%Document{data: %ResourceObject{} = resource_object} = document, view, conn),
    do: denormalize_resource(document, resource_object, view, conn)

  defp denormalize_resource(document, %ResourceObject{} = resource_object, view, conn) do
    %{}
    |> denormalize_id(resource_object, view, conn)
    |> denormalize_attributes(resource_object, view, conn)
    |> denormalize_relationships(resource_object, document, view, conn)
  end

  defp denormalize_id(params, resource_object, view, %Conn{
         private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}
       }) do
    client_generated_ids = API.get_config(jsonapi_plug.api, [:client_generated_ids], false)

    if client_generated_ids && is_nil(resource_object.id) do
      raise InvalidDocument,
        message: "Resource ID not received in request and API requires Client-Generated IDs",
        reference: "https://jsonapi.org/format/1.0/#crud-creating-client-ids"
    end

    Map.put(params, to_string(view.id_attribute()), resource_object.id)
  end

  defp denormalize_attributes(params, %ResourceObject{} = resource_object, view, conn) do
    Enum.reduce(view.attributes(), params, fn attribute, params ->
      name = View.field_name(attribute)
      deserialize = View.field_option(attribute, :deserialize)
      key = to_string(View.field_option(attribute, :name) || name)

      case Map.fetch(resource_object.attributes, recase_field(conn, name)) do
        {:ok, _value} when deserialize == false ->
          params

        {:ok, value} when is_function(deserialize, 2) ->
          Map.put(params, key, deserialize.(value, conn))

        {:ok, value} ->
          Map.put(params, key, value)

        :error ->
          params
      end
    end)
  end

  defp denormalize_relationships(
         params,
         %ResourceObject{relationships: relationships},
         %Document{} = document,
         view,
         conn
       ) do
    Enum.reduce(view.relationships(), params, fn relationship, params ->
      name = View.field_name(relationship)
      key = to_string(View.field_option(relationship, :name) || name)
      related_view = View.field_option(relationship, :view)
      related_many = View.field_option(relationship, :many)
      related_relationships = Map.get(relationships, to_string(name))

      case {related_many, related_relationships} do
        {_many, nil} ->
          params

        {true, related_relationships} when is_list(related_relationships) ->
          value =
            Enum.map(
              related_relationships,
              &find_related_relationship(document, &1, related_view, conn)
            )

          Map.put(params, key, value)

        {_many, related_relationships} when is_list(related_relationships) ->
          raise InvalidDocument,
            message: "List of resources for one-to-one relationship during normalization",
            reference: nil

        {true, _related_data} ->
          raise InvalidDocument,
            message: "Single resource for many relationship during normalization",
            reference: nil

        {_many, %RelationshipObject{data: nil}} ->
          Map.put(params, key <> "_id", nil)

        {_many,
         %RelationshipObject{data: %ResourceIdentifierObject{} = resource_identifier} =
             related_relationship} ->
          value =
            find_related_relationship(
              document,
              related_relationship,
              related_view,
              conn
            )

          params
          |> Map.put(key, value)
          |> Map.put(key <> "_id", resource_identifier.id)
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
         view,
         conn
       ) do
    Enum.find_value(document.included || [], fn
      %ResourceObject{id: ^id, type: ^type} = resource_object ->
        denormalize_resource(document, resource_object, view, conn)

      %ResourceObject{} ->
        nil
    end)
  end

  @impl Normalizer
  def normalize(view, conn, data, meta, options) do
    %Document{meta: meta}
    |> normalize_data(view, conn, data, options)
    |> normalize_links(view, conn, data, options)
    |> normalize_included(view, conn, data, options)
    |> included_to_list()
  end

  defp included_to_list(%Document{included: nil} = document), do: document

  defp included_to_list(%Document{included: included} = document),
    do: %Document{document | included: MapSet.to_list(included)}

  defp normalize_data(document, _view, _conn, nil = _data, _options),
    do: document

  defp normalize_data(document, view, conn, data, options) when is_list(data) do
    %Document{document | data: Enum.map(data, &normalize_resource(view, conn, &1, options))}
  end

  defp normalize_data(document, view, conn, data, options) do
    %Document{document | data: normalize_resource(view, conn, data, options)}
  end

  defp normalize_resource(view, conn, data, options) do
    %ResourceObject{}
    |> normalize_id(view, conn, data, options)
    |> normalize_type(view, conn, data, options)
    |> normalize_attributes(view, conn, data, options)
    |> normalize_relationships(view, conn, data, options)
  end

  defp normalize_id(resource_object, view, _conn, data, _options),
    do: %ResourceObject{resource_object | id: view.id(data)}

  defp normalize_type(resource_object, view, _conn, _data, _options),
    do: %ResourceObject{resource_object | type: view.type()}

  defp normalize_attributes(resource_object, view, conn, data, _options) do
    %ResourceObject{
      resource_object
      | attributes:
          view.attributes()
          |> requested_fields(view, conn)
          |> Enum.reduce(%{}, fn attribute, attributes ->
            name = View.field_name(attribute)
            key = View.field_option(attribute, :name) || View.field_name(attribute)

            case View.field_option(attribute, :serialize) do
              false ->
                attributes

              serialize when serialize in [true, nil] ->
                value = Map.get(data, key)

                Map.put(attributes, recase_field(conn, name), value)

              serialize when is_function(serialize, 2) ->
                value = serialize.(data, conn)

                Map.put(attributes, recase_field(conn, name), value)
            end
          end)
    }
  end

  defp normalize_relationships(resource_object, view, conn, data, _options) do
    %ResourceObject{
      resource_object
      | relationships:
          view.relationships()
          |> Enum.filter(&relationship_loaded?(Map.get(data, elem(&1, 0))))
          |> Enum.into(%{}, fn relationship ->
            name = View.field_name(relationship)
            key = View.field_option(relationship, :name) || View.field_name(relationship)
            related_data = Map.get(data, key)
            related_view = View.field_option(relationship, :view)
            related_many = View.field_option(relationship, :many)

            case {related_many, related_data} do
              {false, related_data} when is_list(related_data) ->
                raise InvalidDocument,
                  message: "List of resources given to render for one-to-one relationship",
                  reference: nil

              {true, _related_data} when not is_list(related_data) ->
                raise InvalidDocument,
                  message: "Single resource given to render for many relationship",
                  reference: nil

              {_related_many, related_data} ->
                {
                  recase_field(conn, name),
                  normalize_relationship(related_view, conn, related_data)
                }
            end
          end)
    }
  end

  defp normalize_relationship(view, conn, data) when is_list(data) do
    %RelationshipObject{
      data:
        Enum.map(
          data,
          &%ResourceIdentifierObject{
            id: view.id(&1),
            type: view.type(),
            meta: view.meta(&1, conn)
          }
        ),
      links: %{self: View.url_for_relationship(view, data, conn, view.type())},
      meta: view.meta(data, conn)
    }
  end

  defp normalize_relationship(view, conn, data) do
    %RelationshipObject{
      data: %ResourceIdentifierObject{
        id: view.id(data),
        type: view.type(),
        meta: view.meta(data, conn)
      },
      links: %{self: View.url_for_relationship(view, data, conn, view.type())},
      meta: view.meta(data, conn)
    }
  end

  defp normalize_links(
         %Document{} = document,
         view,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       )
       when is_list(data) do
    links =
      data
      |> view.links(conn)
      |> Map.merge(pagination_links(view, conn, data, jsonapi_plug.page, options))
      |> Map.merge(%{self: Pagination.url_for(view, data, conn, jsonapi_plug.page)})

    %Document{document | links: links}
  end

  defp normalize_links(%Document{} = document, view, conn, data, _options) do
    links =
      data
      |> view.links(conn)
      |> Map.merge(%{self: View.url_for(view, data, conn)})

    %Document{document | links: links}
  end

  defp pagination_links(
         view,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resources,
         page,
         options
       ) do
    if pagination = API.get_config(jsonapi_plug.api, [:pagination]) do
      pagination.paginate(view, resources, conn, page, options)
    else
      %{}
    end
  end

  defp pagination_links(_view, _resources, _conn, _page, _options), do: %{}

  defp normalize_included(%Document{data: nil} = document, _view, _conn, _data, _options),
    do: document

  defp normalize_included(
         document,
         view,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} = conn,
         data,
         options
       ) do
    view.relationships()
    |> Enum.filter(&get_in(include, [elem(&1, 0)]))
    |> Enum.reduce(
      document,
      &normalize_resource_included(&2, view, conn, data, options, &1)
    )
  end

  defp normalize_included(document, _view, _conn, _data, _options), do: document

  defp normalize_resource_included(document, view, conn, data, options, relationship)
       when is_list(data) do
    Enum.reduce(
      data,
      document,
      &normalize_resource_included(&2, view, conn, &1, options, relationship)
    )
  end

  defp normalize_resource_included(
         %Document{} = document,
         _view,
         conn,
         data,
         options,
         relationship
       ) do
    name = View.field_name(relationship)
    related_data = Map.get(data, name)
    related_loaded? = relationship_loaded?(related_data)
    related_view = View.field_option(relationship, :view)
    related_many = View.field_option(relationship, :many)

    included =
      case {related_loaded?, related_many, related_data} do
        {true, true, related_data} when is_list(related_data) ->
          MapSet.union(
            document.included || MapSet.new(),
            MapSet.new(
              Enum.map(
                related_data,
                &normalize_resource(related_view, conn, &1, options)
              )
            )
          )

        {true, _related_many, related_data} when is_list(related_data) ->
          raise InvalidDocument,
            message: "List of resources given to render for one-to-one relationship",
            reference: nil

        {true, true, _related_data} ->
          raise InvalidDocument,
            message: "Single resource given to render for many relationship",
            reference: nil

        {true, _related_many, related_data} ->
          MapSet.put(
            document.included || MapSet.new(),
            normalize_resource(related_view, conn, related_data, options)
          )

        {false, _related_many, _related_data} ->
          document.included
      end

    normalize_included(
      %Document{document | included: included},
      related_view,
      %Conn{
        conn
        | private: %{
            conn.private
            | jsonapi_plug: %JSONAPIPlug{
                conn.private.jsonapi_plug
                | include: get_in(conn.private.jsonapi_plug.include, [name])
              }
          }
      },
      related_data,
      options
    )
  end

  defp recase_field(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}}, field),
    do: JSONAPIPlug.recase(field, API.get_config(jsonapi_plug.api, [:case], :camelize))

  defp recase_field(_conn, field),
    do: JSONAPIPlug.recase(field, :camelize)

  defp relationship_loaded?(nil), do: false
  defp relationship_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: false
  defp relationship_loaded?(_value), do: true

  defp requested_fields(attributes, view, %Conn{
         private: %{jsonapi_plug: %JSONAPIPlug{fields: fields}}
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
end
