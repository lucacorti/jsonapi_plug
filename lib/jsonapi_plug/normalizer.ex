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

  ```elixir
  defmodule MyApp.API.Normalizer
    ...

    @behaviour JSONAPIPlug.Normalizer

    ...
  end
  ```

  and by configuring it in your api configuration:

  ```elixir
  config :my_app, MyApp.API, normalizer: MyApp.API.Normalizer
  ```

  You can return an error during parsing by raising `JSONAPIPlug.Exceptions.InvalidDocument` at
  any point in your normalizer code.
  """

  alias JSONAPIPlug.{
    API,
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    Pagination,
    Resource
  }

  alias Plug.Conn

  @type t :: module()
  @type params :: term()
  @type value :: term()

  @callback resource_params :: params() | no_return()
  @callback denormalize_attribute(
              params(),
              Resource.field_name(),
              term()
            ) ::
              params() | no_return()
  @callback denormalize_relationship(
              params(),
              RelationshipObject.t() | [RelationshipObject.t()],
              Resource.field_name(),
              term()
            ) ::
              params() | no_return()
  @callback normalize_attribute(params(), Resource.field_name()) :: value() | no_return()

  @doc "Transforms a JSON:API Document user data"
  @spec denormalize(Document.t(), Resource.t(), Conn.t()) :: Conn.params() | no_return()
  def denormalize(%Document{data: nil}, _resource, _conn), do: %{}

  def denormalize(%Document{data: resource_objects} = document, resource, conn)
      when is_list(resource_objects),
      do: Enum.map(resource_objects, &denormalize_resource(document, &1, resource, conn))

  def denormalize(
        %Document{data: %ResourceObject{} = resource_object} = document,
        resource,
        conn
      ),
      do: denormalize_resource(document, resource_object, resource, conn)

  defp denormalize_resource(
         document,
         %ResourceObject{} = resource_object,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn
       ) do
    normalizer = resource.normalizer() || API.get_config(jsonapi_plug.api, [:normalizer])

    normalizer.resource_params()
    |> denormalize_id(resource_object, resource, conn, normalizer)
    |> denormalize_attributes(resource_object, resource, conn, normalizer)
    |> denormalize_relationships(resource_object, document, resource, conn, normalizer)
  end

  defp denormalize_id(
         params,
         %ResourceObject{id: nil},
         _resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}},
         _normalizer
       ) do
    if API.get_config(jsonapi_plug.api, [:client_generated_ids], false) do
      raise InvalidDocument,
        message: "Resource ID not received in request and API requires Client-Generated IDs",
        reference: "https://jsonapi.org/format/1.0/#crud-creating-client-ids"
    end

    params
  end

  defp denormalize_id(params, %ResourceObject{} = resource_object, resource, _conn, normalizer),
    do: normalizer.denormalize_attribute(params, resource.id_attribute(), resource_object.id)

  defp denormalize_attributes(
         params,
         %ResourceObject{} = resource_object,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

    Enum.reduce(resource.attributes(), params, fn attribute, params ->
      denormalize_attribute(params, resource_object, resource, conn, attribute, case, normalizer)
    end)
  end

  defp denormalize_attribute(params, resource_object, resource, conn, attribute, case, normalizer) do
    name = Resource.field_name(attribute)
    key = to_string(Resource.field_option(attribute, :name) || name)

    case Map.fetch(resource_object.attributes, resource.recase_field(name, case)) do
      {:ok, value} ->
        case Resource.field_option(attribute, :deserialize) do
          false ->
            params

          serialize when serialize in [true, nil] ->
            normalizer.denormalize_attribute(params, key, value)

          {module, function, args} ->
            value = apply(module, function, [value, conn | args])
            normalizer.denormalize_attribute(params, key, value)

          deserialize when is_function(deserialize) ->
            value = deserialize.(value, conn)
            normalizer.denormalize_attribute(params, key, value)
        end

      :error ->
        params
    end
  end

  defp denormalize_relationships(
         params,
         %ResourceObject{relationships: relationships},
         %Document{} = document,
         resource,
         conn,
         normalizer
       ) do
    Enum.reduce(resource.relationships(), params, fn relationship, params ->
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
              &find_related_relationship(document, &1, related_resource, conn)
            )

          normalizer.denormalize_relationship(params, related_relationships, key, value)

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

        {_many, related_relationship} ->
          value =
            find_related_relationship(
              document,
              related_relationship,
              related_resource,
              conn
            )

          normalizer.denormalize_relationship(params, related_relationship, key, value)
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
  @spec normalize(
          Resource.t(),
          Conn.t() | nil,
          Resource.data() | nil,
          Resource.meta() | nil,
          Resource.options()
        ) ::
          Document.t() | no_return()
  def normalize(resource, conn, data, meta, options) do
    %Document{meta: meta}
    |> normalize_data(resource, conn, data, options)
    |> normalize_links(resource, conn, data, options)
    |> normalize_included(resource, conn, data, options)
    |> included_to_list()
  end

  defp included_to_list(%Document{included: nil} = document), do: document

  defp included_to_list(%Document{included: included} = document),
    do: %Document{document | included: MapSet.to_list(included)}

  defp normalize_data(document, _resource, _conn, nil = _data, _options),
    do: document

  defp normalize_data(document, resource, conn, data, options) when is_list(data) do
    %Document{document | data: Enum.map(data, &normalize_resource(resource, conn, &1, options))}
  end

  defp normalize_data(document, resource, conn, data, options) do
    %Document{document | data: normalize_resource(resource, conn, data, options)}
  end

  defp normalize_resource(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       ) do
    normalizer = resource.normalizer() || API.get_config(jsonapi_plug.api, [:normalizer])

    %ResourceObject{}
    |> normalize_id(resource, conn, data, options, normalizer)
    |> normalize_type(resource, conn, data, options)
    |> normalize_attributes(resource, conn, data, options, normalizer)
    |> normalize_relationships(resource, conn, data, options, normalizer)
  end

  defp normalize_id(resource_object, resource, _conn, data, _options, normalizer),
    do: %ResourceObject{
      resource_object
      | id: to_string(normalizer.normalize_attribute(data, resource.id_attribute()))
    }

  defp normalize_type(resource_object, resource, _conn, _data, _options),
    do: %ResourceObject{resource_object | type: resource.type()}

  defp normalize_attributes(
         resource_object,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         _options,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

    %ResourceObject{
      resource_object
      | attributes:
          resource.attributes()
          |> requested_fields(resource, conn)
          |> Enum.reduce(%{}, fn attribute, attributes ->
            name = Resource.field_name(attribute)
            key = Resource.field_option(attribute, :name) || Resource.field_name(attribute)

            case Resource.field_option(attribute, :serialize) do
              false ->
                attributes

              serialize when serialize in [true, nil] ->
                value = normalizer.normalize_attribute(data, key)
                Map.put(attributes, resource.recase_field(name, case), value)

              serialize when is_function(serialize, 2) ->
                value = serialize.(data, conn)
                Map.put(attributes, resource.recase_field(name, case), value)

              {module, function, args} ->
                value = apply(module, function, [data, conn | args])
                Map.put(attributes, resource.recase_field(name, case), value)
            end
          end)
    }
  end

  defp normalize_relationships(
         resource_object,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         _options,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

    %ResourceObject{
      resource_object
      | relationships:
          resource.relationships()
          |> Enum.filter(&relationship_loaded?(Map.get(data, elem(&1, 0))))
          |> Enum.into(%{}, fn relationship ->
            name = Resource.field_name(relationship)
            key = Resource.field_option(relationship, :name) || Resource.field_name(relationship)
            related_data = Map.get(data, key)
            related_resource = Resource.field_option(relationship, :resource)
            related_many = Resource.field_option(relationship, :many)

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
                  resource.recase_field(name, case),
                  %RelationshipObject{
                    data:
                      normalize_relationship(related_resource, conn, related_data, normalizer),
                    meta: resource.meta(data, conn)
                  }
                  |> relationship_links(resource, data, conn)
                }
            end
          end)
    }
  end

  defp relationship_links(
         %RelationshipObject{} = relationship_object,
         resource,
         data,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn
       ) do
    if API.get_config(jsonapi_plug.api, [:links]) do
      %{
        relationship_object
        | links: %{
            self: Resource.url_for_relationship(resource, data, conn, resource.type())
          }
      }
    else
      relationship_object
    end
  end

  defp relationship_links(
         %RelationshipObject{} = relationship_object,
         resource,
         data,
         conn
       ) do
    %{
      relationship_object
      | links: %{
          self: Resource.url_for_relationship(resource, data, conn, resource.type())
        }
    }
  end

  defp normalize_relationship(resource, conn, data, normalizer) when is_list(data),
    do: Enum.map(data, &normalize_relationship(resource, conn, &1, normalizer))

  defp normalize_relationship(resource, conn, data, normalizer) do
    %ResourceIdentifierObject{
      id: to_string(normalizer.normalize_attribute(data, resource.id_attribute())),
      type: resource.type(),
      meta: resource.meta(data, conn)
    }
  end

  defp normalize_links(
         %Document{} = document,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       )
       when is_list(data) do
    %Document{
      document
      | links:
          data
          |> resource.links(conn)
          |> Map.merge(pagination_links(resource, conn, data, jsonapi_plug.page, options))
          |> Map.merge(%{self: Pagination.url_for(resource, data, conn, jsonapi_plug.page)})
    }
  end

  defp normalize_links(%Document{} = document, resource, conn, data, _options) do
    links =
      data
      |> resource.links(conn)
      |> Map.merge(%{self: Resource.url_for(resource, data, conn)})

    %Document{document | links: links}
  end

  defp pagination_links(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resources,
         page,
         options
       ) do
    if pagination = API.get_config(jsonapi_plug.api, [:pagination]) do
      pagination.paginate(resource, resources, conn, page, options)
    else
      %{}
    end
  end

  defp pagination_links(_resource, _resources, _conn, _page, _options), do: %{}

  defp normalize_included(%Document{} = document, _resource, _conn, nil, _options),
    do: document

  defp normalize_included(
         document,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       ) do
    resource.relationships()
    |> Enum.filter(&get_in(jsonapi_plug.include, [elem(&1, 0)]))
    |> Enum.reduce(
      document,
      &normalize_resource_included(&2, resource, conn, data, options, &1)
    )
  end

  defp normalize_included(document, _resource, _conn, _data, _options), do: document

  defp normalize_resource_included(document, resource, conn, data, options, relationship)
       when is_list(data) do
    Enum.reduce(
      data,
      document,
      &normalize_resource_included(&2, resource, conn, &1, options, relationship)
    )
  end

  defp normalize_resource_included(
         %Document{} = document,
         _resource,
         conn,
         data,
         options,
         relationship
       ) do
    name = Resource.field_name(relationship)
    related_data = Map.get(data, name)
    related_loaded? = relationship_loaded?(related_data)
    related_resource = Resource.field_option(relationship, :resource)
    related_many = Resource.field_option(relationship, :many)

    included =
      case {related_loaded?, related_many, related_data} do
        {true, true, related_data} when is_list(related_data) ->
          MapSet.union(
            document.included || MapSet.new(),
            MapSet.new(
              Enum.map(
                related_data,
                &normalize_resource(related_resource, conn, &1, options)
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
            normalize_resource(related_resource, conn, related_data, options)
          )

        {false, _related_many, _related_data} ->
          document.included
      end

    normalize_included(
      %Document{document | included: included},
      related_resource,
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

  defp relationship_loaded?(nil), do: false
  defp relationship_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: false
  defp relationship_loaded?(_value), do: true

  defp requested_fields(attributes, resource, %Conn{
         private: %{jsonapi_plug: %JSONAPIPlug{fields: fields}}
       })
       when is_map(fields) do
    case fields[resource.type()] do
      nil ->
        attributes

      fields when is_list(fields) ->
        Enum.filter(attributes, fn attribute -> Resource.field_name(attribute) in fields end)
    end
  end

  defp requested_fields(attributes, _resource, _conn), do: attributes
end
