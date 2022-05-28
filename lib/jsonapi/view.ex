defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines certain callbacks to configure proper
  rendering of your JSONAPI documents.

      defmodule PostView do
        use JSONAPI.View, resource: Post

        @impl JSONAPI.View
        def attributes, do: [:id, :text, :body]

        @impl JSONAPI.View
        def relationships,
          do: [
            author: [view: UserView],
            comments: [many: true, view: CommentView]
          ]
      end

      defmodule UserView do
        use JSONAPI.View, resource: User

        @impl JSONAPI.View
        def attributes, do: [:id, :username]
      end

      defmodule CommentView do
        use JSONAPI.View, resource: Comment

        @impl JSONAPI.View
        def attributes, do: [:id, :text]

        @impl JSONAPI.View
        def relationships, do: [user: [view: UserView]]
      end

      defmodule DogView do
        use JSONAPI.View, resource: Dog
      end

  You can now call `View.render(UserView, user, conn)` and it will render a valid jsonapi doc.

  ## Fields

  By default, the resulting JSON document consists of attributes, defined in the `attributes/0`
  function. You can define custom attributes or override attributes by defining a
  2-arity function inside the view that takes `resource` and `conn` as arguments and has
  the same name as the field it will be producing:

      defmodule UserView do
        use JSONAPI.View, resource: User

        @impl JSONAPI.View
        def attributes, do: [:id, :username, :fullname]

        def fullname(resource, conn), do: "fullname"
      end

  ## Relationships

  The relationships callback expects that a keyword list is returned
  configuring the information you will need. If you have the following Ecto
  Model setup

      defmodule User do
        schema "users" do
          field :username
          has_many :posts
          belongs_to :image
        end
      end

  and the includes setup from above. If your Post has loaded the author and the
  query asks for it then it will be loaded.

  So for example:
  `GET /posts?include=post.author` if the author record is loaded on the Post, and you are using
  the `JSONAPI.Plug.Request` it will be included in the `includes` section of the JSONAPI document.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be camelized.
  """

  alias JSONAPI.{API, Document, Document.ErrorObject, Resource, Resource}
  alias Plug.Conn

  @type t :: module()
  @type options :: keyword()
  @type data :: Resource.t() | [Resource.t()]

  @type attribute_opts :: [to: Resource.field()]
  @type relationship_opts :: [many: boolean(), to: Resource.field(), view: t()]

  @callback id(Resource.t()) :: Resource.id()
  @callback id_attribute :: Resource.field()
  @callback attributes :: [Resource.field() | keyword(attribute_opts())]
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback path :: String.t() | nil
  @callback relationships :: [{Resource.field(), keyword(relationship_opts())}]
  @callback resource :: Resource.t()
  @callback type :: Resource.type()

  defmacro __using__(opts \\ []) do
    {id_attribute, opts} = Keyword.pop(opts, :id_attribute, :id)
    {path, opts} = Keyword.pop(opts, :path)

    {resource, _opts} = Keyword.pop(opts, :resource)

    unless resource do
      raise "You must pass the :resource option to JSONAPI.View"
    end

    quote do
      @behaviour JSONAPI.View

      @__id_attribute__ unquote(id_attribute)
      @__path__ unquote(path)
      @__resource__ struct(unquote(resource))
      @__resource_type__ unquote(resource)
                         |> Module.split()
                         |> List.last()
                         |> String.downcase()
                         |> Resource.inflect(:dasherize)

      @impl JSONAPI.View
      def id(resource) do
        case Map.fetch(resource, id_attribute()) do
          {:ok, id} -> to_string(id)
          :error -> raise "Resources must have an id defined"
        end
      end

      @impl JSONAPI.View
      def id_attribute, do: @__id_attribute__

      @impl JSONAPI.View
      def attributes, do: []

      @impl JSONAPI.View
      def links(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def meta(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def path, do: @__path__

      @impl JSONAPI.View
      def relationships, do: []

      @impl JSONAPI.View
      def resource, do: @__resource__

      @impl JSONAPI.View
      def type, do: @__resource_type__

      defoverridable JSONAPI.View
    end
  end

  @spec for_related_type(t(), Resource.type()) :: t() | nil
  def for_related_type(view, type) do
    Enum.find_value(
      view.relationships(),
      fn {_relationship, options} ->
        relationship_view = Keyword.fetch!(options, :view)

        if relationship_view.type() == type do
          relationship_view
        else
          nil
        end
      end
    )
  end

  @spec render(t(), data() | nil, Conn.t() | nil, Document.meta() | nil, options()) ::
          Document.t()
  def render(view, data, conn \\ nil, meta \\ nil, options \\ []),
    do: Document.serialize(%Document{data: data, meta: meta}, view, conn, options)

  @spec send_error(Conn.t(), Conn.status(), [ErrorObject.t()]) :: Conn.t()
  def send_error(conn, status, errors) do
    conn
    |> Conn.update_resp_header("content-type", JSONAPI.mime_type(), & &1)
    |> Conn.send_resp(
      status,
      Jason.encode!(%Document{
        errors:
          Enum.map(errors, fn %ErrorObject{} = error ->
            %ErrorObject{error | status: Integer.to_string(status)}
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
