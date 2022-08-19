defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines how to render your JSON:API resource:

      defmodule MyApp.UsersView do
        use JSONAPI.View,
          type: "user",
          attributes: [:id, :username]
      end

  You can now call `UsersView.render("show.json", %{data: user})` or `View.render(UsersView, conn, user)`
  to render a valid JSON:API document from your data. If you use phoenix, you can use:

      conn
      |> put_view(UsersView)
      |> render("show.json", %{data: user})

  in your controller to render the document in the same way.

  ## Attributes

  By default, the resulting JSON document consists of attributes taken from your data.
  Only attributes defined on the view will be (de)serialized. You can customize attributes
  by using a keyword list of options instead:

      defmodule MyApp.UsersView do
        use JSONAPI.View,
          type: "user",
          attributes: [
            username: nil,
            fullname: [deserialize: false, serialize: &fullname/2]
          ]

        defp fullname(resource, conn), do: "\#{resouce.first_name} \#{resource.last_name}"
      end

  For example here we are defining a computed attribute by passing the `serialize` option a function reference.
  Serialization functions take `resource` and `conn` as arguments and return the value to be added to the resource.
  The `deserialize` option set to `false` makes sure the attribute is ignored when deserializing requests.

  ## Relationships

  Relationships are defined similarly, by passing the `relationships` option to `use JSONAPI.View`.

      defmodule MyApp.PostsView do
        use JSONAPI.View,
          type: "post",
          attributes: [:text, :body]
          relationships: [
            author: [view: MyApp.UsersView],
            comments: [many: true, view: MyApp.CommentsView]
          ]
      end

      defmodule MyApp.CommentsView do
        alias MyApp.UsersView

        use JSONAPI.View,
          type: "comment",
          attributes: [:text]
          relationships: [post: [view: MyApp.PostsView]]
      end

  When requesting `GET /posts?include=author`, if the author key is present on the data you pass from the controller
  and you are using the `JSONAPI.Plug.Request` it will be included in the `included` section of the JSONAPI response.

  ## Links

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. If you need to use different values for some reason, you can specify them
  passing `JSONAPI.API` configuration options in your api configuration:

      config :my_app, MyApp.MyAPI, host: "adifferenthost.com"
  """

  alias JSONAPI.{API, Document, Document.ErrorObject, Normalizer, Resource, Resource}
  alias Plug.Conn

  @attribute_schema [
    name: [
      doc: "Maps the resource attribute name to the given key.",
      type: :atom,
      required: false
    ],
    serialize: [
      doc:
        "Controls attribute serialization. Can be either a boolean (do/don't serialize) or a function reference returning the attribute value to be serialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
      required: false,
      default: true
    ],
    deserialize: [
      doc:
        "Controls attribute deserialization. Can be either a boolean (do/don't deserialize) or a function reference returning the attribute value to be deserialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
      required: false,
      default: true
    ]
  ]

  @relationship_schema [
    name: [
      doc: "Maps the resource relationship name to the given key.",
      type: :atom,
      required: false
    ],
    many: [
      doc: "Specifies a to many relationship.",
      type: :boolean,
      required: false,
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
              required: false
            ],
            id_attribute: [
              doc:
                "Attribute on your data to be used as the JSON:API resource id. Defaults to :id",
              type: :atom,
              required: false
            ],
            path: [
              doc: "A custom path to be used for the resource. Defaults to the type value.",
              type: :string,
              required: false
            ],
            relationships: [
              doc:
                "Resource relationships. This will be used to (de)serialize requests/responses",
              type: :keyword_list,
              keys: [*: [type: :non_empty_keyword_list, keys: @relationship_schema]],
              required: false
            ],
            type: [
              doc: "Resource type. To be used as the JSON:API resource type value",
              type: :string,
              required: true
            ]
          )

  @type t :: module()

  @typedoc """
  View options\n#{NimbleOptions.docs(@schema)}
  """
  @type options :: keyword()

  @type data :: Resource.t() | [Resource.t()]

  @typedoc """
  Attribute options\n#{NimbleOptions.docs(NimbleOptions.new!(@attribute_schema))}
  """
  @type attribute_options :: [
          name: Resource.field(),
          serialize: boolean() | (Resource.t(), Conn.t() -> term()),
          deserialize: boolean() | (Resource.t(), Conn.t() -> term())
        ]

  @type attributes :: [Resource.field()] | [{Resource.field(), attribute_options()}]

  @typedoc """
  Relationship options\n#{NimbleOptions.docs(NimbleOptions.new!(@relationship_schema))}
  """
  @type relationship_options :: [many: boolean(), name: Resource.field(), view: t()]
  @type relationships :: [{Resource.field(), relationship_options()}]

  @type field ::
          Resource.field() | {Resource.field(), attribute_options() | relationship_options()}

  @callback id(Resource.t()) :: Resource.id()
  @callback id_attribute :: Resource.field()
  @callback attributes :: attributes()
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback path :: String.t() | nil
  @callback relationships :: relationships()
  @callback type :: Resource.type()

  defmacro __using__(options \\ []) do
    {attributes, options} = Keyword.pop(options, :attributes, [])
    {id_attribute, options} = Keyword.pop(options, :id_attribute, :id)
    {path, options} = Keyword.pop(options, :path)
    {relationships, options} = Keyword.pop(options, :relationships, [])
    {type, _options} = Keyword.pop(options, :type)

    if field =
         Enum.concat(attributes, relationships)
         |> Enum.find(&(JSONAPI.View.field_name(&1) in [:id, :type])) do
      name = JSONAPI.View.field_name(field)
      view = Module.split(__CALLER__.module) |> List.last()

      raise "Illegal field name '#{name}' for view #{view}. Check out https://jsonapi.org/format/#document-resource-object-fields for more information."
    end

    quote do
      NimbleOptions.validate!(unquote(options), unquote(Macro.escape(@schema)))

      @behaviour JSONAPI.View

      @impl JSONAPI.View
      def id(resource) do
        case Map.fetch(resource, unquote(id_attribute)) do
          {:ok, id} -> to_string(id)
          :error -> raise "Resources must have an id defined"
        end
      end

      @impl JSONAPI.View
      def id_attribute, do: unquote(id_attribute)

      @impl JSONAPI.View
      def attributes, do: unquote(attributes)

      @impl JSONAPI.View
      def links(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def meta(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def path, do: unquote(path)

      @impl JSONAPI.View
      def relationships, do: unquote(relationships)

      @impl JSONAPI.View
      def type, do: unquote(type)

      defoverridable JSONAPI.View

      def render(action, assigns)
          when action in ["create.json", "index.json", "show.json", "update.json"] do
        JSONAPI.View.render(
          __MODULE__,
          Map.get(assigns, :conn),
          Map.get(assigns, :data),
          Map.get(assigns, :meta),
          Map.get(assigns, :options)
        )
      end

      def render(action, _assigns) do
        raise "invalid action #{action}, use one of create.json, index.json, show.json, update.json"
      end
    end
  end

  @spec field_name(field()) :: Resource.field()
  def field_name(field) when is_atom(field), do: field
  def field_name({name, nil}), do: name
  def field_name({name, options}) when is_list(options), do: name

  def field_name(field) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @spec field_option(field(), atom()) :: term()
  def field_option(name, _option) when is_atom(name), do: nil
  def field_option({_name, nil}, _option), do: nil

  def field_option({_name, options}, option) when is_list(options),
    do: Keyword.get(options, option)

  def field_option(field, _option, _default) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @spec for_related_type(t(), Resource.type()) :: t() | nil
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

  @spec render(t(), Conn.t(), data() | nil, Document.meta() | nil, options()) ::
          Document.t() | no_return()
  def render(view, conn, data \\ nil, meta \\ nil, options \\ []) do
    view
    |> Normalizer.normalize(conn, data, meta, options)
    |> Document.serialize()
  end

  @spec send_error(Conn.t(), Conn.status(), [ErrorObject.t()]) :: Conn.t()
  def send_error(conn, status, errors) do
    conn
    |> Conn.update_resp_header("content-type", JSONAPI.mime_type(), & &1)
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

  @spec url_for_relationship(t(), Resource.t(), Conn.t() | nil, Resource.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end

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

  defp scheme(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, scheme: scheme}),
    do: to_string(API.get_config(jsonapi.api, :scheme, scheme))

  defp scheme(_conn), do: nil

  defp host(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, host: host}),
    do: API.get_config(jsonapi.api, :host, host)

  defp host(_conn), do: nil

  defp namespace(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}}) do
    case API.get_config(jsonapi.api, :namespace) do
      nil -> ""
      namespace -> "/" <> namespace
    end
  end

  defp namespace(_conn), do: ""

  defp port(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, port: port} = conn) do
    case API.get_config(jsonapi.api, :port, port) do
      nil -> nil
      port -> if port == URI.default_port(scheme(conn)), do: nil, else: port
    end
  end

  defp port(_conn), do: nil
end
