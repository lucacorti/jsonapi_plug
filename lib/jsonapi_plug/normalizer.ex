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

  alias JSONAPIPlug.{API, Document, Pagination, Resource}

  alias JSONAPIPlug.Document.{
    ErrorObject,
    RelationshipObject,
    ResourceIdentifierObject,
    ResourceObject
  }

  alias JSONAPIPlug.Exceptions.{InvalidAttributes, InvalidDocument}

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
              RelationshipObject.t(),
              Resource.field_name(),
              term()
            ) ::
              params() | no_return()
  @callback normalize_attribute(params(), Resource.field_name()) :: value() | no_return()

  @doc "Transforms a JSON:API Document into user data"
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
        errors: [
          %ErrorObject{
            title: "Resource ID not received in request and API requires Client-Generated IDs",
            detail: "https://jsonapi.org/format/1.0/#crud-creating-client-ids"
          }
        ]
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
    |> validate_params(resource, case)
  end

  defp validate_params(params, resource, case) do
    case resource.validate(params) do
      :ok ->
        params

      {:error, errors} ->
        raise InvalidAttributes,
          message: "Resource '#{resource.type()}' is invalid.",
          errors:
            Enum.map(errors, fn {msg, "#/" <> pointer} ->
              name = resource.recase_field(pointer, case)

              %ErrorObject{
                title: "Attribute '#{name}' is invalid.",
                detail: msg,
                source: %{pointer: "/data/attributes/" <> name}
              }
            end)
    end
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
         %ResourceObject{} = resource_object,
         %Document{} = document,
         resource,
         conn,
         normalizer
       ) do
    Enum.reduce(resource.relationships(), params, fn relationship, params ->
      name = Resource.field_name(relationship)
      key = to_string(Resource.field_option(relationship, :name) || name)
      related_resource = Resource.field_option(relationship, :resource)

      case {
        Resource.field_option(relationship, :many),
        resource_object.relationships[to_string(name)]
      } do
        {_many?, nil} ->
          params

        {true, %RelationshipObject{data: data} = relationship_object} when is_list(data) ->
          value =
            Enum.map(
              data,
              &denormalize_relationship(document, &1, related_resource, normalizer, conn)
            )

          normalizer.denormalize_relationship(params, relationship_object, key, value)

        {true, _related_data} ->
          raise InvalidDocument,
            message: "Invalid value for '#{resource.type()}' relationship '#{name}'",
            errors: [
              %ErrorObject{
                title: "Invalid value for '#{resource.type()}' relationship '#{name}'",
                detail: "Relationship '#{name}' is one-to-many but a single value was received."
              }
            ]

        {false, %RelationshipObject{data: data}} when is_list(data) ->
          raise InvalidDocument,
            message: "Invalid value for '#{resource.type()}' relationship '#{name}'",
            errors: [
              %ErrorObject{
                title: "Invalid value for '#{resource.type()}' relationship '#{name}'",
                detail: "Relationship '#{name}' is one-to-one but a list was received."
              }
            ]

        {false, %RelationshipObject{data: nil} = relationship_object} ->
          normalizer.denormalize_relationship(params, relationship_object, key, nil)

        {false,
         %RelationshipObject{data: %ResourceIdentifierObject{} = data} = relationship_object} ->
          value = denormalize_relationship(document, data, related_resource, normalizer, conn)
          normalizer.denormalize_relationship(params, relationship_object, key, value)
      end
    end)
  end

  defp denormalize_relationship(
         document,
         %ResourceIdentifierObject{id: id, type: type},
         related_resource,
         normalizer,
         conn
       ) do
    Enum.find_value(
      document.included || [],
      normalizer.denormalize_attribute(%{}, related_resource.id_attribute(), id),
      fn
        %ResourceObject{id: ^id, type: ^type} = resource_object ->
          denormalize_resource(document, resource_object, related_resource, conn)

        %ResourceObject{} ->
          nil
      end
    )
  end

  @doc "Transforms user data into a JSON:API Document"
  @spec normalize(
          Resource.t(),
          Conn.t(),
          Resource.data() | nil,
          Resource.meta() | nil,
          Resource.options()
        ) ::
          Document.t() | no_return()
  def normalize(resource, conn, data, meta, options) do
    %Document{
      meta: meta,
      data: normalize_data(resource, conn, data, options),
      links: normalize_links(resource, conn, data, options),
      included:
        normalize_included(MapSet.new(), resource, conn, data, options)
        |> MapSet.to_list()
    }
  end

  defp normalize_data(_resource, _conn, nil = _data, _options), do: nil

  defp normalize_data(resource, conn, data, options) when is_list(data) do
    Enum.map(data, &normalize_resource(resource, conn, &1, options))
  end

  defp normalize_data(resource, conn, data, options) do
    normalize_resource(resource, conn, data, options)
  end

  defp normalize_resource(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       ) do
    normalizer = resource.normalizer() || API.get_config(jsonapi_plug.api, [:normalizer])

    %ResourceObject{
      id: normalize_id(resource, data, normalizer),
      type: resource.type(),
      attributes: normalize_attributes(resource, conn, data, options, normalizer),
      relationships: normalize_relationships(resource, conn, data, options, normalizer)
    }
  end

  defp normalize_id(resource, data, normalizer),
    do: data |> normalizer.normalize_attribute(resource.id_attribute()) |> to_string()

  defp normalize_attributes(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         _options,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

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
  end

  defp normalize_relationships(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         _options,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

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
            message: "Invalid value for '#{resource.type()}' relationship '#{name}'",
            errors: [
              %ErrorObject{
                title: "Invalid value for '#{resource.type()}' relationship '#{name}'",
                detail: "Relationship '#{name}' is one-to-one but a list was received."
              }
            ]

        {true, _related_data} when not is_list(related_data) ->
          raise InvalidDocument,
            message: "Invalid value for '#{resource.type()}' relationship '#{name}'",
            errors: [
              %ErrorObject{
                title: "Invalid value for '#{resource.type()}' relationship '#{name}'",
                detail: "Relationship '#{name}' is one-to-many but a single value was received."
              }
            ]

        {_related_many, related_data} ->
          {
            resource.recase_field(name, case),
            %RelationshipObject{
              data: normalize_relationship(related_resource, conn, related_data, normalizer),
              meta: resource.meta(data, conn),
              links: relationship_links(resource, data, conn)
            }
          }
      end
    end)
  end

  defp relationship_links(
         resource,
         data,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn
       ) do
    if API.get_config(jsonapi_plug.api, [:links]) do
      %{
        self: Resource.url_for_relationship(resource, data, conn, resource.type())
      }
    end
  end

  defp relationship_links(
         resource,
         data,
         conn
       ) do
    %{
      self: Resource.url_for_relationship(resource, data, conn, resource.type())
    }
  end

  defp normalize_relationship(resource, conn, data, normalizer) when is_list(data),
    do: Enum.map(data, &normalize_relationship(resource, conn, &1, normalizer))

  defp normalize_relationship(resource, conn, data, normalizer) do
    %ResourceIdentifierObject{
      id: data |> normalizer.normalize_attribute(resource.id_attribute()) |> to_string(),
      type: resource.type(),
      meta: resource.meta(data, conn)
    }
  end

  defp normalize_links(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       )
       when is_list(data) do
    data
    |> resource.links(conn)
    |> Map.merge(pagination_links(resource, conn, data, jsonapi_plug.page, options))
    |> Map.put(:self, Pagination.url_for(resource, data, conn, jsonapi_plug.page))
  end

  defp normalize_links(resource, conn, data, _options) do
    data
    |> resource.links(conn)
    |> Map.put(:self, Resource.url_for(resource, data, conn))
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

  defp normalize_included(included, _resource, _conn, nil, _options),
    do: included

  defp normalize_included(
         included,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         data,
         options
       ) do
    resource.relationships()
    |> Enum.filter(&get_in(jsonapi_plug.include, [elem(&1, 0)]))
    |> Enum.reduce(
      included,
      &normalize_resource_included(&2, resource, conn, data, options, &1)
    )
  end

  defp normalize_resource_included(included, resource, conn, data, options, relationship)
       when is_list(data) do
    Enum.reduce(
      data,
      included,
      &normalize_resource_included(&2, resource, conn, &1, options, relationship)
    )
  end

  defp normalize_resource_included(
         included,
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

    case {related_loaded?, related_many, related_data} do
      {true, true, related_data} when is_list(related_data) ->
        related_data
        |> Enum.map(&normalize_resource(related_resource, conn, &1, options))
        |> MapSet.new()
        |> MapSet.union(included)

      {true, _related_many, related_data} when is_list(related_data) ->
        raise InvalidDocument,
          message: "Invalid value for '#{related_resource.type()}' relationship '#{name}'",
          errors: [
            %ErrorObject{
              title: "Invalid value for '#{related_resource.type()}' relationship '#{name}'",
              detail: "Relationship '#{name}' is one-to-one but a list was received."
            }
          ]

      {true, true, _related_data} ->
        raise InvalidDocument,
          message: "Invalid value for '#{related_resource.type()}' relationship '#{name}'",
          errors: [
            %ErrorObject{
              title: "Invalid value for '#{related_resource.type()}' relationship '#{name}'",
              detail: "Relationship '#{name}' is one-to-many but a single value was received."
            }
          ]

      {true, _related_many, related_data} ->
        MapSet.put(
          included,
          normalize_resource(related_resource, conn, related_data, options)
        )

      {false, _related_many, _related_data} ->
        included
    end
    |> normalize_included(
      related_resource,
      update_in(conn.private.jsonapi_plug.include, & &1[name]),
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
