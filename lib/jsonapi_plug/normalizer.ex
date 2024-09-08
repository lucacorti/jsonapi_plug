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
    Resource,
    Resource.Attribute,
    Resource.Links,
    Resource.Meta
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
              RelationshipObject.t(),
              Resource.field_name(),
              term()
            ) ::
              params() | no_return()

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
    jsonapi_plug.normalizer.resource_params()
    |> denormalize_id(resource_object, resource, conn, jsonapi_plug.normalizer)
    |> denormalize_attributes(resource_object, resource, conn, jsonapi_plug.normalizer)
    |> denormalize_relationships(
      resource_object,
      document,
      resource,
      conn,
      jsonapi_plug.normalizer
    )
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
    do:
      normalizer.denormalize_attribute(
        params,
        Resource.id_attribute(resource),
        resource_object.id
      )

  defp denormalize_attributes(
         params,
         %ResourceObject{} = resource_object,
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         normalizer
       ) do
    Enum.reduce(Resource.attributes(resource), params, fn attribute, params ->
      denormalize_attribute(
        params,
        resource_object,
        resource,
        conn,
        attribute,
        jsonapi_plug.case,
        normalizer
      )
    end)
  end

  defp denormalize_attribute(params, resource_object, resource, conn, attribute, case, normalizer) do
    key = to_string(Resource.field_option(resource, attribute, :name) || attribute)

    case Map.fetch(resource_object.attributes, Resource.recase_field(resource, attribute, case)) do
      {:ok, value} ->
        case Resource.field_option(resource, attribute, :deserialize) do
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
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         normalizer
       ) do
    case = API.get_config(jsonapi_plug.api, [:case], :camelize)

    Enum.reduce(Resource.relationships(resource), params, fn relationship, params ->
      key = to_string(Resource.field_option(resource, relationship, :name) || relationship)
      related_resource = struct(Resource.field_option(resource, relationship, :resource))

      case {
        Resource.field_option(resource, relationship, :many),
        resource_object.relationships[Resource.recase_field(resource, relationship, case)]
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
            message: "Single resource for many relationship during normalization",
            reference: nil

        {false, %RelationshipObject{data: data}} when is_list(data) ->
          raise InvalidDocument,
            message: "List of resources for one-to-one relationship during normalization",
            reference: nil

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
      normalizer.denormalize_attribute(%{}, Resource.id_attribute(related_resource), id),
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
          Conn.t(),
          Resource.t() | [Resource.t()] | nil,
          Document.meta() | nil,
          Resource.options()
        ) ::
          Document.t() | no_return()
  def normalize(conn, resource_or_resources, meta, options) do
    %Document{
      meta: meta,
      data: normalize_data(conn, resource_or_resources, options),
      links: normalize_links(conn, resource_or_resources, options),
      included:
        normalize_included(MapSet.new(), conn, resource_or_resources, options)
        |> MapSet.to_list()
    }
  end

  defp normalize_data(_conn, nil, _options), do: nil

  defp normalize_data(conn, resources, options) when is_list(resources),
    do: Enum.map(resources, &normalize_resource(conn, &1, options))

  defp normalize_data(conn, resource, options), do: normalize_resource(conn, resource, options)

  defp normalize_resource(conn, resource, options) do
    %ResourceObject{
      id: normalize_id(resource, conn),
      type: Resource.type(resource),
      attributes: normalize_attributes(conn, resource, options),
      relationships: normalize_relationships(conn, resource, options)
    }
  end

  defp normalize_id(resource, conn),
    do: Attribute.render(resource, Resource.id_attribute(resource), conn) |> to_string()

  defp normalize_attributes(
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resource,
         _options
       ) do
    Resource.attributes(resource)
    |> requested_fields(resource, conn)
    |> Enum.reduce(%{}, fn attribute, attributes ->
      key = Resource.field_option(resource, attribute, :name) || attribute

      case Resource.field_option(resource, attribute, :serialize) do
        false ->
          attributes

        serialize when serialize in [true, nil] ->
          value = Attribute.render(resource, key, conn)

          Map.put(
            attributes,
            Resource.recase_field(resource, attribute, jsonapi_plug.case),
            value
          )

        serialize when is_function(serialize, 2) ->
          value = serialize.(resource, conn)

          Map.put(
            attributes,
            Resource.recase_field(resource, attribute, jsonapi_plug.case),
            value
          )

        {module, function, args} ->
          value = apply(module, function, [resource, conn | args])

          Map.put(
            attributes,
            Resource.recase_field(resource, attribute, jsonapi_plug.case),
            value
          )
      end
    end)
  end

  defp normalize_relationships(
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resource,
         _options
       ) do
    Resource.relationships(resource)
    |> Enum.filter(&relationship_loaded?(Map.get(resource, &1)))
    |> Enum.into(%{}, fn relationship ->
      key = Resource.field_option(resource, relationship, :name) || relationship
      related_resource = Map.get(resource, key)
      related_many = Resource.field_option(resource, relationship, :many)

      case {related_many, related_resource} do
        {false, related_resources} when is_list(related_resources) ->
          raise InvalidDocument,
            message: "List of resources given to render for one-to-one relationship",
            reference: nil

        {true, _related_resource} when not is_list(related_resource) ->
          raise InvalidDocument,
            message: "Single resource given to render for many relationship",
            reference: nil

        {_related_many, related_resource} ->
          {
            Resource.recase_field(resource, relationship, jsonapi_plug.case),
            %RelationshipObject{
              data: normalize_relationship(conn, related_resource),
              meta: Meta.meta(resource, conn),
              links: relationship_links(resource, conn)
            }
          }
      end
    end)
  end

  defp relationship_links(
         resource,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn
       ) do
    if API.get_config(jsonapi_plug.api, [:links]) do
      %{
        self: JSONAPIPlug.url_for_relationship(resource, conn, Resource.type(resource))
      }
    end
  end

  defp normalize_relationship(conn, resources) when is_list(resources),
    do: Enum.map(resources, &normalize_relationship(conn, &1))

  defp normalize_relationship(conn, resource) do
    %ResourceIdentifierObject{
      id: Attribute.render(resource, Resource.id_attribute(resource), conn) |> to_string(),
      type: Resource.type(resource),
      meta: Meta.meta(resource, conn)
    }
  end

  defp normalize_links(conn, nil, _options), do: %{self: JSONAPIPlug.url_for(nil, conn)}
  defp normalize_links(conn, [], _options), do: %{self: JSONAPIPlug.url_for([], conn)}

  defp normalize_links(
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         [resource | _] = resources,
         options
       ) do
    Links.links(resource, conn)
    |> Map.merge(pagination_links(conn, resources, jsonapi_plug.page, options))
    |> Map.put(:self, Pagination.url_for(resources, conn, jsonapi_plug.page))
  end

  defp normalize_links(conn, resource, _options) do
    resource
    |> Links.links(conn)
    |> Map.put(:self, JSONAPIPlug.url_for(resource, conn))
  end

  defp pagination_links(
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resources,
         page,
         options
       )
       when is_list(resources) do
    if pagination = API.get_config(jsonapi_plug.api, [:pagination]) do
      pagination.paginate(resources, conn, page, options)
    else
      %{}
    end
  end

  defp pagination_links(_conn, _resource, _page, _options), do: %{}

  defp normalize_included(included, _conn, nil, _options),
    do: included

  defp normalize_included(included, conn, resources, options) when is_list(resources),
    do: Enum.reduce(resources, included, &normalize_included(&2, conn, &1, options))

  defp normalize_included(
         included,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resource,
         options
       ) do
    Resource.relationships(resource)
    |> Enum.filter(&get_in(jsonapi_plug.include, [&1]))
    |> Enum.reduce(
      included,
      &normalize_resource_included(&2, conn, resource, options, &1)
    )
  end

  defp normalize_resource_included(
         included,
         conn,
         resource,
         options,
         relationship
       ) do
    related_data = Map.get(resource, relationship)
    related_loaded? = relationship_loaded?(related_data)
    related_many = Resource.field_option(resource, relationship, :many)

    case {related_loaded?, related_many, related_data} do
      {true, true, related_data} when is_list(related_data) ->
        related_data
        |> Enum.map(&normalize_resource(conn, &1, options))
        |> MapSet.new()
        |> MapSet.union(included)

      {true, _related_many, related_data} when is_list(related_data) ->
        raise InvalidDocument,
          message: "List of resources given to render for one-to-one relationship",
          reference: nil

      {true, true, _related_data} ->
        raise InvalidDocument,
          message: "Single resource given to render for many relationship",
          reference: nil

      {true, _related_many, _related_data} ->
        MapSet.put(
          included,
          normalize_resource(conn, related_data, options)
        )

      {false, _related_many, _related_data} ->
        included
    end
    |> normalize_included(
      update_in(conn.private.jsonapi_plug.include, & &1[relationship]),
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
    case fields[Resource.type(resource)] do
      nil ->
        attributes

      fields when is_list(fields) ->
        Enum.filter(attributes, &(&1 in fields))
    end
  end

  defp requested_fields(attributes, _resource, _conn), do: attributes
end
