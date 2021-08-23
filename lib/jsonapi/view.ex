defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines certain callbacks to configure proper
  rendering of your JSONAPI documents.

      defmodule PostView do
        use JSONAPI.View, resource: Post

        @impl JSONAPI.View
        def attributes(_resource), do: [:id, :text, :body]

        @impl JSONAPI.View
        def type, do: "post"

        @impl JSONAPI.View
        def relationships(_resource) do
          [author: UserView,
           comments: CommentView]
        end
      end

      defmodule UserView do
        use JSONAPI.View, resource: User

        @impl JSONAPI.View
        def attributes(_resource), do: [:id, :username]

        @impl JSONAPI.View
        def type, do: "user"

        @impl JSONAPI.View
        def relationships(_resource), do: []
      end

      defmodule CommentView do
        use JSONAPI.View, resource: Comment

        @impl JSONAPI.View
        def attributes(_resource), do: [:id, :text]

        @impl JSONAPI.View
        def type, do: "comment"

        @impl JSONAPI.View
        def relationships(_resource), do: [user: UserView]
      end

      defmodule DogView do
        use JSONAPI.View, resource: Dog, namespace: "pupperz-api"
      end

  You can now call `UserView.show(user, conn, conn.params)` and it will render
  a valid jsonapi doc.

  ## Fields

  By default, the resulting JSON document consists of attributes, defined in the `attributes/0`
  function. You can define custom attributes or override current attributes by defining a
  2-arity function inside the view that takes `resource` and `conn` as arguments and has
  the same name as the field it will be producing. Refer to our `fullname/2` example below.

      defmodule UserView do
        use JSONAPI.View, resource: User

        @impl JSONAPI.View
        def attributes(_resource), do: [:id, :username, :fullname]

        @impl JSONAPI.View
        def type, do: "user"

        @impl JSONAPI.View
        def relationships(_resource), do: []

        def fullname(resource, conn), do: "fullname"
      end

  In order to use [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
  you must include the `JSONAPI.QueryParser` plug.

  ## Relationships

  Currently the relationships callback expects that a map is returned
  configuring the information you will need. If you have the following Ecto
  Model setup

      defmodule User do
        schema "users" do
          field :username
          has_many :posts
          has_one :image
        end
      end

  and the includes setup from above. If your Post has loaded the author and the
  query asks for it then it will be loaded.

  So for example:
  `GET /posts?include=post.author` if the author record is loaded on the Post, and you are using
  the `JSONAPI.QueryParser` it will be included in the `includes` section of the JSONAPI document.

  ## Options
    * `:host` (binary) - Allows the `host` to be overrided for generated URLs. Defaults to `host` of the supplied `conn`.

    * `:scheme` (atom) - Enables configuration of the HTTP scheme for generated URLS.  Defaults to `scheme` from the provided `conn`.

    * `:namespace` (binary) - Allows the namespace of a given resource. This may be
      configured globally or set on the View itself. Note that if you have
      a globally defined namespace and need to *remove* the namespace for a
      resource, set the namespace to a blank String.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be underscored and not dashed.
  """

  alias JSONAPI.{Document, Paginator, Resource}
  alias Plug.Conn

  @type t :: module()
  @type options :: keyword()
  @type data :: Resource.t() | [Resource.t()]

  @callback id(Resource.t()) :: Resource.id()
  @callback attributes(Resource.t()) :: [Resource.field()]
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback namespace :: String.t() | nil
  @callback paginator :: Paginator.t() | nil
  @callback path :: String.t() | nil
  @callback relationships(Resource.t()) :: [{Resource.field(), t()}]
  @callback resource :: Resource.t()
  @callback type :: Resource.type()

  defmacro __using__(opts \\ []) do
    {resource, opts} = Keyword.pop!(opts, :resource)
    {namespace, opts} = Keyword.pop(opts, :namespace)
    {path, opts} = Keyword.pop(opts, :path)
    {paginator, _opts} = Keyword.pop(opts, :paginator)

    quote do
      alias JSONAPI.{Document, Resource, View}

      @behaviour View

      @__namespace__ unquote(namespace)
      @__paginator__ unquote(paginator)
      @__path__ unquote(path)
      @__resource__ struct(unquote(resource))

      @__attributes__ Resource.attributes(@__resource__)
      @__relationships__ Enum.concat(
                           Resource.has_one(@__resource__),
                           Resource.has_many(@__resource__)
                         )
      @__resource_type__ Resource.type(@__resource__)

      @impl View
      def id(resource), do: Resource.id(resource)

      @impl View
      def attributes(_resource), do: @__attributes__

      @impl View
      def links(_resource, _conn), do: %{}

      @impl View
      def meta(_resource, _conn), do: %{}

      @impl View
      def namespace, do: @__namespace__

      @impl View
      def paginator, do: @__paginator__

      @impl View
      def path, do: @__path__

      @impl View
      def relationships(_resource), do: @__relationships__

      @impl View
      def resource, do: @__resource__

      @impl View
      def type, do: @__resource_type__

      defoverridable View
    end
  end

  @spec for_related_type(t(), Resource.type()) :: t() | nil
  def for_related_type(view, type) do
    case Enum.find(
           view.relationships(view.resource()),
           fn {_relationship, relationship_view} ->
             relationship_view.type() == type
           end
         ) do
      {_relationship, view} -> view
      _ -> nil
    end
  end

  @spec render(t(), data() | nil, Conn.t() | nil, Document.meta() | nil, options()) ::
          Document.t()
  def render(view, data, conn \\ nil, meta \\ nil, options \\ []),
    do: Document.serialize(view, data, conn, meta, options)

  @spec url_for(t(), data() | nil, Conn.t() | nil) :: String.t()
  def url_for(view, resource, conn) when is_nil(resource) or is_list(resource) do
    render_url(conn, Enum.join([namespace(view), view.path() || view.type()], "/"))
  end

  def url_for(view, resource, conn) do
    render_url(
      conn,
      Enum.join([namespace(view), view.path() || view.type(), view.id(resource)], "/")
    )
  end

  @spec namespace(t()) :: String.t()
  def namespace(view), do: view.namespace() || Application.get_env(:jsonapi, :namespace, "")

  defp render_url(%Conn{scheme: scheme, host: host}, "/" <> _ = path) do
    URI.to_string(%URI{
      scheme: Application.get_env(:jsonapi, :scheme, to_string(scheme)),
      host: Application.get_env(:jsonapi, :host, host),
      path: path
    })
  end

  defp render_url(%Conn{scheme: scheme, host: host}, path) do
    URI.to_string(%URI{
      scheme: Application.get_env(:jsonapi, :scheme, to_string(scheme)),
      host: Application.get_env(:jsonapi, :host, host),
      path: "/" <> path
    })
  end

  defp render_url(_conn, "/" <> _ = path),
    do: URI.to_string(%URI{path: path})

  defp render_url(_conn, path),
    do: URI.to_string(%URI{path: "/" <> path})

  @spec url_for_relationship(t(), Resource.t(), Conn.t() | nil, Resource.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end
end
