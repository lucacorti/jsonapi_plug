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
        use JSONAPI.View, resource: Dog
      end

  You can now call `View.render(UserView, user, conn)` and it will render a valid jsonapi doc.

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
  you must include the `JSONAPI.Request` plug.

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
  the `JSONAPI.Request` it will be included in the `includes` section of the JSONAPI document.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be camelized.
  """

  alias JSONAPI.{API, Document, Document.ErrorObject, Resource, Resource.Field}
  alias Plug.Conn

  @type t :: module()
  @type options :: keyword()
  @type data :: Resource.t() | [Resource.t()]

  @type attribute_opts :: [to: Field.name()]
  @type relationship_opts :: [many: boolean(), to: Field.name(), view: t()]

  @callback id(Resource.t()) :: Resource.id()
  @callback id_attribute :: Field.name()
  @callback attributes :: [Field.name() | keyword(attribute_opts())]
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback path :: String.t() | nil
  @callback relationships :: [{Field.name(), keyword(relationship_opts())}]
  @callback resource :: Resource.t()
  @callback type :: Resource.type()

  defmacro __using__(opts \\ []) do
    {id_attribute, opts} = Keyword.pop(opts, :id_attribute, :id)
    {path, opts} = Keyword.pop(opts, :path)

    {resource, opts} = Keyword.pop(opts, :resource)

    unless resource do
      raise "You must pass the :resource option to JSONAPI.View"
    end

    {type, _opts} = Keyword.pop(opts, :type)

    unless type do
      raise "You must pass the :type option to JSONAPI.View"
    end

    quote do
      @behaviour JSONAPI.View

      @__id_attribute__ unquote(id_attribute)
      @__path__ unquote(path)
      @__resource__ struct(unquote(resource))
      @__resource_type__ unquote(type)

      @impl JSONAPI.View
      def id(resource) do
        case Map.fetch(resource, id_attribute()) do
          {:ok, id} -> to_string(id)
          :error -> raise "Resources must have and id defined"
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

  @spec send_error(Conn.t(), pos_integer(), [ErrorObject.t()]) :: Conn.t()
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

  @spec url_for(t(), data() | nil, Conn.t() | nil) :: String.t()
  def url_for(view, resource, conn) when is_nil(resource) or is_list(resource) do
    conn
    |> render_url([view.path() || view.type()])
    |> to_string()
  end

  def url_for(view, resource, conn) do
    conn
    |> render_url([view.path() || view.type(), view.id(resource)])
    |> to_string()
  end

  defp render_url(
         %Conn{assigns: %{jsonapi: %JSONAPI{api: api}}, scheme: scheme, host: host},
         path
       ) do
    namespace =
      case API.get_config(api, :namespace) do
        nil -> ""
        namespace -> "/" <> namespace
      end

    %URI{
      scheme: to_string(API.get_config(api, :scheme, scheme)),
      host: API.get_config(api, :host, host),
      path: Enum.join([namespace | path], "/")
    }
  end

  defp render_url(_conn, path), do: %URI{path: "/" <> Enum.join(path, "/")}

  @spec url_for_relationship(t(), Resource.t(), Conn.t() | nil, Resource.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end
end
