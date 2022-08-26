defmodule JSONAPIPlug.View do
  @moduledoc """
  A View is simply a module that describes how to render your data as JSON:API resources.

  You can implement a view by "use-ing" the `JSONAPIPlug.View` module, which is recommeded, or
  by adopting the `JSONAPIPlug.View` behaviour and implementing all of the callback functions:

      defmodule MyApp.UsersView do
        use JSONAPIPlug.View,
          type: "user",
          attributes: [:id, :username]
      end

  See `t:options/0` for all available options you can pass to "use" `JSONAPIPlug.View`.

  You can now call `UsersView.render("show.json", %{data: user})` or `View.render(UsersView, conn, user)`
  to render a valid JSON:API document from your data. If you use phoenix, you can use:

      conn
      |> put_view(UsersView)
      |> render("show.json", %{data: user})

  in your controller functions to render the document in the same way.

  ## Attributes

  By default, the resulting JSON document consists of resources taken from your data.
  Only resource  attributes defined on the view will be (de)serialized. You can customize
  how attributes are handled by passing a keyword list of options:

      defmodule MyApp.UsersView do
        use JSONAPIPlug.View,
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

  Relationships are defined by passing the `relationships` option to `use JSONAPIPlug.View`.

      defmodule MyApp.PostsView do
        use JSONAPIPlug.View,
          type: "post",
          attributes: [:text, :body]
          relationships: [
            author: [view: MyApp.UsersView],
            comments: [many: true, view: MyApp.CommentsView]
          ]
      end

      defmodule MyApp.CommentsView do
        alias MyApp.UsersView

        use JSONAPIPlug.View,
          type: "comment",
          attributes: [:text]
          relationships: [post: [view: MyApp.PostsView]]
      end

  When requesting `GET /posts?include=author`, if the author key is present on the data you pass from the
  controller it will appear in the `included` section of the JSON:API response.

  ## Links

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. If you need to use different values for some reason, you can override them
  using `JSONAPIPlug.API` configuration options in your api configuration:

      config :my_app, MyApp.API, host: "adifferenthost.com"
  """

  alias JSONAPIPlug.{API, Document, Document.ErrorObject, Document.ResourceObject}
  alias Plug.Conn

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
    view: [
      doc: "Specifies the view to be used to serialize the relationship",
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
            id_attribute: [
              doc:
                "Attribute on your data to be used as the JSON:API resource id. Defaults to :id",
              type: :atom,
              default: :id
            ],
            path: [
              doc: "A custom path to be used for the resource. Defaults to the type value.",
              type: :string
            ],
            relationships: [
              doc:
                "Resource relationships. This will be used to (de)serialize requests/responses",
              type: :keyword_list,
              keys: [*: [type: :non_empty_keyword_list, keys: @relationship_schema]],
              default: []
            ],
            type: [
              doc: "Resource type. To be used as the JSON:API resource type value",
              type: :string,
              required: true
            ]
          )

  @typedoc """
  View module

  A Module adopting the `JSONAPIPlug.View` behaviour
  """
  @type t :: module()

  @typedoc """
  View options

  #{NimbleOptions.docs(@schema)}
  """
  @type options :: keyword()

  @typedoc """
  Resource data

  User data representing a single resource
  """
  @type resource :: term()

  @typedoc """
  View data

  View data is either a resource or a list of resources
  """
  @type data :: resource() | [resource()]

  @typedoc """
  View meta

  A free form map containing metadata to be rendered
  """
  @type meta :: Document.meta()

  @typedoc """
  View field name

  The name of a View field (attribute or relationship)
  """
  @type field_name :: atom()

  @typedoc """
  Attribute options\n#{NimbleOptions.docs(NimbleOptions.new!(@attribute_schema))}
  """
  @type attribute_options :: [
          name: field_name(),
          serialize: boolean() | (resource(), Conn.t() -> term()),
          deserialize: boolean() | (resource(), Conn.t() -> term())
        ]

  @typedoc """
  View attributes

  A keyword list composed of attribute names and their options
  """
  @type attributes :: [field_name()] | [{field_name(), attribute_options()}]

  @typedoc """
  Relationship options

  #{NimbleOptions.docs(NimbleOptions.new!(@relationship_schema))}
  """
  @type relationship_options :: [many: boolean(), name: field_name(), view: t()]

  @typedoc """
  View attributes

  A keyword list composed of relationship names and their options
  """
  @type relationships :: [{field_name(), relationship_options()}]

  @type field ::
          field_name() | {field_name(), attribute_options() | relationship_options()}

  @doc """
  Resource Id

  Returns the Resource Id of a resource for the view.
  """
  @callback id(resource()) :: ResourceObject.id()

  @doc """
  Resource Id Attribute

  Returns the attribute used to fetch resource ids for resources by the view.
  """
  @callback id_attribute :: field_name()

  @doc """
  Resource attributes

  Returns the keyword list of resource attributes for the view.
  """
  @callback attributes :: attributes()

  @doc """
  Resource links

  Returns the resource links to be returned for resources by the view.
  """
  @callback links(resource(), Conn.t() | nil) :: Document.links()

  @doc """
  Resource meta

  Returns the resource meta to be returned for resources by the view.
  """
  @callback meta(resource(), Conn.t() | nil) :: Document.meta()

  @doc """
  View path

  Returns the path to prepend to resources for the view.
  """
  @callback path :: String.t() | nil

  @doc """
  Resource relationships

  Returns the keyword list of resource relationships for the view.
  """
  @callback relationships :: relationships()

  @doc """
  Resource Type

  Returns the Resource Type of resources for the view.
  """
  @callback type :: ResourceObject.type()

  defmacro __using__(options \\ []) do
    options =
      options
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(@schema)

    attributes = Keyword.fetch!(options, :attributes)
    id_attribute = Keyword.fetch!(options, :id_attribute)
    path = Keyword.get(options, :path)
    relationships = Keyword.fetch!(options, :relationships)
    type = Keyword.fetch!(options, :type)

    if field =
         Stream.concat(attributes, relationships)
         |> Enum.find(&(JSONAPIPlug.View.field_name(&1) in [:id, :type])) do
      name = JSONAPIPlug.View.field_name(field)
      view = Module.split(__CALLER__.module) |> List.last()

      raise "Illegal field name '#{name}' for view #{view}. Check out https://jsonapi.org/format/#document-resource-object-fields for more information."
    end

    quote do
      @behaviour JSONAPIPlug.View

      @impl JSONAPIPlug.View
      def id(resource) do
        case Map.fetch(resource, unquote(id_attribute)) do
          {:ok, id} -> to_string(id)
          :error -> raise "Resources must have an id defined"
        end
      end

      @impl JSONAPIPlug.View
      def id_attribute, do: unquote(id_attribute)

      @impl JSONAPIPlug.View
      def attributes, do: unquote(attributes)

      @impl JSONAPIPlug.View
      def links(_resource, _conn), do: %{}

      @impl JSONAPIPlug.View
      def meta(_resource, _conn), do: %{}

      @impl JSONAPIPlug.View
      def path, do: unquote(path)

      @impl JSONAPIPlug.View
      def relationships, do: unquote(relationships)

      @impl JSONAPIPlug.View
      def type, do: unquote(type)

      defoverridable JSONAPIPlug.View

      if Code.ensure_loaded?(Phoenix) do
        @doc """
        JSONAPIPlug generated view render function

        This render function is autogenerated by JSONAPIPlug because it detected Phoenix
        to be present in your project. It allows you to use the `JSONAPIPlug.View` as a
        standard phoenix view by calling `Phoenix.Controller.render/2` with your assigns:

          ...
          conn
          |> put_view(MyApp.PostsView)
          |> render("update.json", %{data: post})
          ...

        instead of calling `JSONAPIPlug.View.render/5` directly in your controllers.
        It takes the action (one of "create.json", "index.json", "show.json", "update.json") and
        the assings as a keyword list or map with atom keys.
        """
        @spec render(action :: String.t(), assigns :: keyword() | %{atom() => term()}) :: Conn.t()
        def render(action, assigns)
            when action in ["create.json", "index.json", "show.json", "update.json"] do
          JSONAPIPlug.View.render(
            __MODULE__,
            assigns[:conn],
            assigns[:data],
            assigns[:meta],
            assigns[:options]
          )
        end

        def render(action, _assigns) do
          raise "invalid action #{action}, use one of create.json, index.json, show.json, update.json"
        end
      end
    end
  end

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

  def field_option(field, _option, _default) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @doc """
  Related View based on JSON:API type

  Returns the view used for relationships of the requested type byy the passed view.
  """
  @spec for_related_type(t(), ResourceObject.type()) :: t() | nil
  def for_related_type(view, type) do
    Enum.find_value(view.relationships(), fn {_relationship, options} ->
      relationship_view = Keyword.fetch!(options, :view)

      if relationship_view.type() == type do
        relationship_view
      else
        nil
      end
    end)
  end

  @doc """
  Render JSON:API response

  Renders the JSON:API response for the specified View.
  """
  @spec render(t(), Conn.t(), data() | nil, Document.meta() | nil, options()) ::
          Document.t() | no_return()
  def render(
        view,
        %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn,
        data \\ nil,
        meta \\ nil,
        options \\ []
      ) do
    normalizer = API.get_config(jsonapi_plug.api, [:normalizer])

    view
    |> normalizer.normalize(conn, data, meta, options)
    |> Document.serialize()
  end

  @doc false
  @spec send_error(Conn.t(), Conn.status(), [ErrorObject.t()]) :: Conn.t()
  def send_error(conn, status, errors) do
    conn
    |> Conn.update_resp_header("content-type", JSONAPIPlug.mime_type(), & &1)
    |> Conn.send_resp(
      status,
      Jason.encode!(%Document{
        errors:
          Enum.map(errors, fn %ErrorObject{} = error ->
            code = Conn.Status.code(status)
            %ErrorObject{error | status: to_string(code), title: Conn.Status.reason_phrase(code)}
          end)
      })
    )
    |> Conn.halt()
  end

  @doc """
  Generate relationships link

  Generates the relationships link for a resource.
  """
  @spec url_for_relationship(t(), resource(), Conn.t() | nil, ResourceObject.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end

  @doc """
  Generates the resource link

  Generates the resource link for a resource.
  """
  @spec url_for(t(), data() | nil, Conn.t() | nil) :: String.t()
  def url_for(view, resource, conn) when is_nil(resource) or is_list(resource) do
    conn
    |> render_uri([view.path() || view.type()])
    |> to_string()
  end

  def url_for(view, resource, conn) do
    conn
    |> render_uri([view.path() || view.type(), view.id(resource)])
    |> to_string()
  end

  defp render_uri(%Conn{} = conn, path) do
    %URI{
      scheme: scheme(conn),
      host: host(conn),
      path: Enum.join([namespace(conn) | path], "/"),
      port: port(conn)
    }
  end

  defp render_uri(_conn, path), do: %URI{path: "/" <> Enum.join(path, "/")}

  defp scheme(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, scheme: scheme}),
    do: to_string(API.get_config(jsonapi_plug.api, [:scheme], scheme))

  defp scheme(_conn), do: nil

  defp host(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, host: host}),
    do: API.get_config(jsonapi_plug.api, [:host], host)

  defp host(_conn), do: nil

  defp namespace(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}}) do
    case API.get_config(jsonapi_plug.api, [:namespace]) do
      nil -> ""
      namespace -> "/" <> namespace
    end
  end

  defp namespace(_conn), do: ""

  defp port(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, port: port} = conn) do
    case API.get_config(jsonapi_plug.api, [:port], port) do
      nil -> nil
      port -> if port == URI.default_port(scheme(conn)), do: nil, else: port
    end
  end

  defp port(_conn), do: nil
end
