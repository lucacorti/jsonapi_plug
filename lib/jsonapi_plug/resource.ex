defmodule JSONAPIPlug.Resource do
  @moduledoc """
  A Resource is simply a module that describes how to render your data as JSON:API resources.

  You can implement a resource by "use-ing" the `JSONAPIPlug.Resource` module:

      defmodule MyApp.UsersResource do
        use JSONAPIPlug.Resource,
          type: "user",
          attributes: [:name, :surname, :username]
      end

  See `t:options/0` for all available options you can pass to `use JSONAPIPlug.Resource`.

  You can now call `Usersrender("show.json", %{data: user})` or `render(UsersResource, conn, user)`
  to render a valid JSON:API document from your data. If you use phoenix, you can use:

      render(conn, "show.json", %{data: user})

  in your controller functions to render the document in the same way.

  ## Attributes

  By default, the resulting JSON document consists of resources taken from your data.
  Only resource  attributes defined on the resource will be (de)serialized. You can customize
  how attributes are handled by passing a keyword list of options:

      defmodule MyApp.UsersResource do
        use JSONAPIPlug.Resource,
          type: "user",
          attributes: [
            username: nil,
            fullname: [deserialize: false, serialize: &fullname/2]
          ]

        defp fullname(resource, conn), do: "\#{resouce.first_name} \#{resource.last_name}"
      end

  In this example we are defining a computed attribute by passing the `serialize` option a function reference.
  Serialization functions take `resource` and `conn` as arguments and return the attribute value to be serialized.
  The `deserialize` option set to `false` makes sure the attribute is not deserialized when receiving a request.

  ## Relationships

  Relationships are defined by passing the `relationships` option to `use JSONAPIPlug.Resource`.

      defmodule MyApp.PostResource do
        use JSONAPIPlug.Resource,
          type: "post",
          attributes: [:text, :body]
          relationships: [
            author: [resource: MyApp.UsersResource],
            comments: [many: true, resource: MyApp.CommentsResource]
          ]
      end

      defmodule MyApp.CommentsResource do
        alias MyApp.UsersResource

        use JSONAPIPlug.Resource,
          type: "comment",
          attributes: [:text]
          relationships: [post: [resource: MyApp.PostResource]]
      end

  When requesting `GET /posts?include=author`, if the author key is present on the data you pass from the
  controller it will appear in the `included` section of the JSON:API response.

  ## Links

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. If you need to use different values for some reason, you can override them
  using `JSONAPIPlug.API` configuration options in your api configuration:

      config :my_app, MyApp.API, host: "adifferenthost.com"
  """

  @attribute_schema [
    name: [
      doc: "Maps the resource attribute name to the given key.",
      type: :atom
    ],
    serialize: [
      doc:
        "Controls attribute serialization. Can be either a boolean (do/don't serialize) or a function reference returning the attribute value to be serialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
      default: true
    ],
    deserialize: [
      doc:
        "Controls attribute deserialization. Can be either a boolean (do/don't deserialize) or a function reference returning the attribute value to be deserialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
      default: true
    ]
  ]

  @relationship_schema [
    name: [
      doc: "Maps the resource relationship name to the given key.",
      type: :atom
    ],
    many: [
      doc: "Specifies a to many relationship.",
      type: :boolean,
      default: false
    ],
    resource: [
      doc: "Specifies the resource to be used to serialize the relationship",
      type: :atom,
      required: true
    ]
  ]

  @schema NimbleOptions.new!(
            attributes: [
              doc:
                "Resource attributes. This will be used to (de)serialize requests/responses:\n\n" <>
                  NimbleOptions.docs(@attribute_schema, nest_level: 1),
              type:
                {:or,
                 [
                   {:list, :atom},
                   {:keyword_list, [*: [type: [keyword_list: [keys: @attribute_schema]]]]}
                 ]},
              default: []
            ],
            case: [
              doc:
                "This option controls how your API's field names will be cased. The current `JSON:API Specification v1.0` recommends dasherizing (e.g. `\"favorite-color\": \"blue\"`), while the upcoming `JSON:API Specification v1.1` recommends camelCase (e.g. `\"favoriteColor\": \"blue\"`).",
              type: {:in, [:camelize, :dasherize, :underscore]},
              default: :camelize
            ],
            client_generated_ids: [
              doc:
                "Enable support for Client-Generated IDs. When enabled, the resources received in requests are supposed to contain a valid 'id'.",
              type: :boolean,
              default: false
            ],
            id_attribute: [
              doc: "Attribute on your data to be used as the JSON:API resource id.",
              type: :atom,
              default: :id
            ],
            relationships: [
              doc:
                "Resource relationships. This will be used to (de)serialize requests/responses",
              type: :keyword_list,
              keys: [*: [type: :non_empty_keyword_list, keys: @relationship_schema]],
              default: []
            ],
            resource: [
              doc: "Resource",
              type: :atom,
              required: true
            ],
            type: [
              doc: "Resource type. To be used as the JSON:API resource type value",
              type: :string,
              required: true
            ]
          )

  alias JSONAPIPlug.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    Resource.Fields,
    Resource.Identity,
    Resource.Links,
    Resource.Meta,
    Resource.Params
  }

  alias Plug.Conn

  defmacro __using__(options) do
    options =
      options
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(@schema)

    if field =
         Stream.concat(options[:attributes], options[:relationships])
         |> Enum.find(&(field_name(&1) in [:id, :type])) do
      name = field_name(field)

      raise "Illegal field name '#{name}' for resource '#{options[:resource]}'. See https://jsonapi.org/format/#document-resource-object-fields for more information."
    end

    quote do
      if Code.ensure_loaded?(Phoenix) do
        @doc """
        JSONAPIPlug generated resource render function

        This render function is autogenerated by JSONAPIPlug because it detected Phoenix
        to be present in your project. It allows you to use the `JSONAPIPlug.Resource` as a
        standard phoenix resource by calling `Phoenix.Controller.render/2` with your assigns:

          ...
          conn
          |> put_resource(MyApp.PostResource)
          |> render("update.json", %{data: post})
          ...

        instead of calling `JSONAPIPlug.render/5` directly in your controllers.
        It takes the action (one of "create.json", "index.json", "show.json", "update.json") and
        the assings as a keyword list or map with atom keys.
        """
        @spec render(action :: String.t(), assigns :: keyword() | %{atom() => term()}) ::
                Document.t() | no_return()
        def render(action, assigns)
            when action in ["create.json", "index.json", "show.json", "update.json"] do
          JSONAPIPlug.render(
            assigns[:conn],
            assigns[:data],
            assigns[:links],
            assigns[:meta]
          )
        end

        def render(action, _assigns) do
          raise "invalid action #{action}, use one of create.json, index.json, show.json, update.json"
        end
      end

      defimpl JSONAPIPlug.Resource.Identity, for: unquote(options[:resource]) do
        def client_generated_ids?(_t), do: unquote(options[:client_generated_ids])
        def id_attribute(_t), do: unquote(options[:id_attribute])
        def type(_t), do: unquote(options[:type])
      end

      defimpl JSONAPIPlug.Resource.Fields, for: unquote(options[:resource]) do
        def attributes(_t), do: unquote(options[:attributes])
        def fields_case(_t), do: unquote(options[:case])
        def relationships(_t), do: unquote(options[:relationships])
      end
    end
  end

  @typedoc "Resource"
  @type t :: struct()

  @type field_case :: :camelize | :dasherize | :underscore

  @type data :: t() | [t()]

  @typedoc """
  Resource field name

  The name of a Resource field (attribute or relationship)
  """
  @type field_name :: atom()

  @typedoc """
  Attribute options\n#{NimbleOptions.docs(NimbleOptions.new!(@attribute_schema))}
  """
  @type attribute_options :: [
          name: field_name(),
          serialize: boolean() | (t(), Conn.t() -> term()),
          deserialize: boolean() | (t(), Conn.t() -> term())
        ]

  @typedoc """
  Resource attributes

  A keyword list composed of attribute names and their options
  """
  @type attributes :: [field_name()] | [{field_name(), attribute_options()}]

  @typedoc """
  Relationship options\n#{NimbleOptions.docs(NimbleOptions.new!(@relationship_schema))}
  """
  @type relationship_options :: [many: boolean(), name: field_name(), resource: t()]

  @typedoc """
  Resource attributes

  A keyword list composed of relationship names and their options
  """
  @type relationships :: [{field_name(), relationship_options()}]

  @typedoc """
  Resource field
  """
  @type field ::
          field_name() | {field_name(), attribute_options() | relationship_options()}

  @typedoc """
  Resource type
  """
  @type type :: String.t()

  @doc """
  Id attribute
  """
  @spec id_attribute(t()) :: field_name()
  def id_attribute(resource), do: Identity.id_attribute(resource)

  @doc """
  Field option

  Returns the name of the attribute or relationship for the field definition.
  """
  @spec field_name(field()) :: field_name()
  def field_name(field) when is_atom(field), do: field
  def field_name({name, nil}), do: name
  def field_name({name, options}) when is_list(options), do: name

  def field_name(field) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @doc """
  Field option

  Returns the value of the attribute or relationship option for the field definition.
  """
  @spec field_option(field(), atom()) :: term()
  def field_option(name, _option) when is_atom(name), do: nil
  def field_option({_name, nil}, _option), do: nil

  def field_option({_name, options}, option) when is_list(options),
    do: Keyword.get(options, option)

  def field_option(field, _option) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @spec field_recase(t(), field_name() | String.t(), field_case() | nil) :: String.t()
  def field_recase(resource, field_name, field_case \\ nil)

  def field_recase(resource, field, nil = _field_case),
    do: recase(field, Fields.fields_case(resource))

  def field_recase(_resource, field, field_case), do: recase(field, field_case)

  @doc """
  Recase resource fields

  Changes the case of resource field names to the specified case, ignoring underscores
  or dashes that are not between letters/numbers.

  ## Examples
    ```
    iex> recase("top_posts", :camelize)
    "topPosts"

    iex> recase(:top_posts, :camelize)
    "topPosts"

    iex> recase("_top_posts", :camelize)
    "_topPosts"

    iex> recase("_top__posts_", :camelize)
    "_top__posts_"

    iex> recase("", :camelize)
    ""

    iex> recase("top_posts", :dasherize)
    "top-posts"

    iex> recase("_top_posts", :dasherize)
    "_top-posts"

    iex> recase("_top__posts_", :dasherize)
    "_top__posts_"

    iex> recase("top-posts", :underscore)
    "top_posts"

    iex> recase(:top_posts, :underscore)
    "top_posts"

    iex> recase("-top-posts", :underscore)
    "-top_posts"

    iex> recase("-top--posts-", :underscore)
    "-top--posts-"

    iex> recase("corgiAge", :underscore)
    "corgi_age"
    ```
  """
  @spec recase(field_name() | String.t(), field_case()) :: String.t()
  def recase(field_name, field_case) when is_atom(field_name),
    do: recase(Atom.to_string(field_name), field_case)

  def recase("", :camelize), do: ""

  def recase(field, :camelize) do
    [h | t] = String.split(field, ~r/(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])/, trim: true)

    Enum.join([String.downcase(h) | Enum.map(t, &String.capitalize/1)])
  end

  def recase(field, :dasherize),
    do: String.replace(field, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")

  def recase(field, :underscore) do
    field
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  @spec fields(t()) :: [field()]
  def fields(resource), do: Enum.concat([attributes(resource), relationships(resource)])

  @spec attributes(t()) :: [field()]
  def attributes(resource), do: Fields.attributes(resource)

  @spec relationships(t()) :: [field()]
  def relationships(resource), do: Fields.relationships(resource)

  @spec fields_names(t()) :: [field()]
  def fields_names(resource),
    do: Enum.concat([attributes_names(resource), relationships_names(resource)])

  @spec attributes_names(t) :: [field_name()]
  def attributes_names(resource), do: Enum.map(attributes(resource), &field_name/1)

  @spec relationships_names(t) :: [field_name()]
  def relationships_names(resource), do: Enum.map(relationships(resource), &field_name/1)

  @spec type(t()) :: type()
  def type(resource), do: Identity.type(resource)

  @doc """
  Render JSON:API response

  Renders the JSON:API response for the specified resources.
  """
  @spec render(Conn.t(), data(), Document.links(), Document.meta()) ::
          Document.t() | no_return()
  def render(conn, resources, links \\ %{}, meta \\ %{}) do
    %Document{}
    |> render_links(conn, links)
    |> render_meta(conn, meta)
    |> render_data(conn, resources)
    |> render_included(conn, resources)
    |> included_to_list()
  end

  defp render_links(
         %Document{} = document,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         links
       ),
       do: %{document | links: Map.merge(jsonapi_plug.api.links(conn), links || %{})}

  defp render_meta(
         %Document{} = document,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         meta
       ),
       do: %{document | links: Map.merge(jsonapi_plug.api.links(conn), meta || %{})}

  defp render_data(document, _conn, nil = _resources),
    do: document

  defp render_data(%Document{} = document, conn, resources)
       when is_list(resources),
       do: %{
         document
         | data: Enum.map(resources, &render_resource(conn, &1))
       }

  defp render_data(%Document{} = document, conn, resource),
    do: %{document | data: render_resource(conn, resource)}

  defp render_resource(conn, resource) do
    %ResourceObject{}
    |> render_resource_id(conn, resource)
    |> render_resource_type(conn, resource)
    |> render_resource_attributes(conn, resource)
    |> render_resource_links(conn, resource)
    |> render_resource_meta(conn, resource)
    |> render_resource_relationships(conn, resource)
  end

  defp render_resource_id(%ResourceObject{} = resource_object, _conn, resource),
    do: %{
      resource_object
      | id: to_string(Params.render_attribute(resource, Identity.id_attribute(resource)))
    }

  defp render_resource_type(%ResourceObject{} = resource_object, _conn, resource),
    do: %{resource_object | type: Identity.type(resource)}

  defp render_resource_attributes(%ResourceObject{} = resource_object, conn, resource) do
    %{
      resource_object
      | attributes:
          attributes(resource)
          |> requested_fields(resource, conn)
          |> Enum.reduce(%{}, fn attribute, attributes ->
            name = field_name(attribute)
            key = field_option(attribute, :name) || field_name(attribute)

            case field_option(attribute, :serialize) do
              false ->
                attributes

              serialize when serialize in [true, nil] ->
                value = Params.render_attribute(resource, key)

                Map.put(attributes, field_recase(resource, name), value)

              serialize when is_function(serialize, 2) ->
                value = serialize.(resource, conn)

                Map.put(attributes, field_recase(resource, name), value)
            end
          end)
    }
  end

  defp render_resource_links(%ResourceObject{} = resource_object, conn, resource),
    do: %{resource_object | links: Links.links(resource, conn)}

  defp render_resource_meta(%ResourceObject{} = resource_object, conn, resource),
    do: %{resource_object | meta: Meta.meta(resource, conn)}

  defp render_resource_relationships(%ResourceObject{} = resource_object, conn, resource) do
    %{
      resource_object
      | relationships:
          relationships(resource)
          |> Enum.filter(&relationship_loaded?(Map.get(resource, elem(&1, 0))))
          |> Enum.into(%{}, fn relationship ->
            name = field_name(relationship)

            key =
              field_option(relationship, :name) ||
                field_name(relationship)

            related_resources = Map.get(resource, key)
            related_many = field_option(relationship, :many)

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
                  field_recase(resource, name),
                  %RelationshipObject{
                    data: render_resource_relationship(related_resources, conn),
                    meta: Meta.meta(resource, conn)
                  }
                }
            end
          end)
    }
  end

  defp render_resource_relationship(related_resources, conn) when is_list(related_resources),
    do: Enum.map(related_resources, &render_resource_relationship(&1, conn))

  defp render_resource_relationship(related_resource, conn) do
    id = id_attribute(related_resource)

    %ResourceIdentifierObject{
      id: to_string(Params.render_attribute(related_resource, id)),
      type: Identity.type(related_resource),
      meta: Meta.meta(related_resource, conn)
    }
  end

  defp render_included(document, _conn, nil = _resources),
    do: document

  defp render_included(document, conn, resources) when is_list(resources),
    do: Enum.reduce(resources, document, &render_included(&2, conn, &1))

  defp render_included(
         document,
         %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
         resource
       ) do
    resource
    |> relationships()
    |> Enum.filter(&get_in(jsonapi_plug.include, [elem(&1, 0)]))
    |> Enum.reduce(
      document,
      &render_resource_included(&2, conn, resource, &1)
    )
  end

  defp render_included(document, _conn, _resource), do: document

  defp render_resource_included(
         %Document{} = document,
         conn,
         resource,
         relationship
       ) do
    name = field_name(relationship)
    related_resource = Map.get(resource, name)
    related_loaded? = relationship_loaded?(related_resource)
    related_many = field_option(relationship, :many)

    included =
      case {related_loaded?, related_many, related_resource} do
        {true, true, related_resource} when is_list(related_resource) ->
          MapSet.union(
            document.included || MapSet.new(),
            MapSet.new(Enum.map(related_resource, &render_resource(conn, &1)))
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
            render_resource(conn, related_resource)
          )

        {false, _related_many, _related_resource} ->
          document.included
      end

    render_included(
      %{document | included: included},
      update_in(conn.private.jsonapi_plug.include, & &1[name]),
      related_resource
    )
  end

  defp included_to_list(%Document{included: nil} = document), do: document

  defp included_to_list(%Document{included: included} = document),
    do: %{document | included: MapSet.to_list(included)}

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
        Enum.filter(attributes, fn attribute -> field_name(attribute) in fields end)
    end
  end

  defp requested_fields(attributes, _resource, _conn), do: attributes

  @spec to_params(Document.t(), data(), Conn.t()) :: Conn.params()
  def to_params(%Document{data: nil}, _resource, _conn), do: %{}

  def to_params(%Document{data: resource_objects} = document, resource, conn)
      when is_list(resource_objects) do
    Enum.map(resource_objects, &resource_to_params(document, &1, resource, conn))
  end

  def to_params(
        %Document{data: %ResourceObject{} = resource_object} = document,
        resource,
        conn
      ) do
    resource_to_params(document, resource_object, resource, conn)
  end

  defp resource_to_params(
         document,
         %ResourceObject{} = resource_object,
         resource,
         conn
       ) do
    Params.init(resource)
    |> resource_id_to_params(resource_object, resource, conn)
    |> resource_attributes_to_params(resource_object, resource, conn)
    |> resource_relationships_to_params(resource_object, document, resource, conn)
  end

  defp resource_id_to_params(
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

  defp resource_id_to_params(params, %ResourceObject{} = resource_object, resource, _conn),
    do:
      Params.attribute_to_params(
        resource,
        params,
        to_string(id_attribute(resource)),
        resource_object.id
      )

  defp resource_attributes_to_params(
         params,
         %ResourceObject{} = resource_object,
         resource,
         conn
       ) do
    resource
    |> attributes()
    |> Enum.reduce(params, fn attribute, params ->
      name = field_name(attribute)
      deserialize = field_option(attribute, :deserialize)
      key = to_string(field_option(attribute, :name) || name)

      case Map.fetch(resource_object.attributes, field_recase(resource, name)) do
        {:ok, _value} when deserialize == false ->
          params

        {:ok, value} when is_function(deserialize, 2) ->
          Params.attribute_to_params(resource, params, key, deserialize.(value, conn))

        {:ok, value} ->
          Params.attribute_to_params(resource, params, key, value)

        :error ->
          params
      end
    end)
  end

  defp resource_relationships_to_params(
         params,
         %ResourceObject{relationships: relationships},
         %Document{} = document,
         resource,
         conn
       ) do
    relationships(resource)
    |> Enum.reduce(params, fn relationship, params ->
      name = field_name(relationship)
      key = to_string(field_option(relationship, :name) || name)
      related_resource = field_option(relationship, :resource)
      related_many = field_option(relationship, :many)
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

          Params.relationship_to_params(resource, params, related_relationships, key, value)

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

          Params.relationship_to_params(resource, params, related_relationship, key, value)
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
        resource_to_params(document, resource_object, resource, conn)

      %ResourceObject{} ->
        nil
    end)
  end
end
