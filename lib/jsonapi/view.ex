defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines certain callbacks to configure proper
  rendering of your JSONAPI documents.

      defmodule PostView do
        use JSONAPI.View, resource: Post

        @impl JSONAPI.View
        def attributes, do: [:id, :text, :body]

        @impl JSONAPI.View
        def type, do: "post"

        @impl JSONAPI.View
        def relationships do
          [author: UserView,
           comments: CommentView]
        end
      end

      defmodule UserView do
        use JSONAPI.View, resource: User

        @impl JSONAPI.View
        def attributes, do: [:id, :username]

        @impl JSONAPI.View
        def type, do: "user"

        @impl JSONAPI.View
        def relationships, do: []
      end

      defmodule CommentView do
        use JSONAPI.View, resource: Comment

        @impl JSONAPI.View
        def attributes, do: [:id, :text]

        @impl JSONAPI.View
        def type, do: "comment"

        @impl JSONAPI.View
        def relationships, do: [user: UserView]
      end

      defmodule DogView do
        use JSONAPI.View, resource: Dog, namespace: "/pupperz-api"
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
        def attributes, do: [:id, :username, :fullname]

        @impl JSONAPI.View
        def type, do: "user"

        @impl JSONAPI.View
        def relationships, do: []

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
      configured globally or overridden on the View itself. Note that if you have
      a globally defined namespace and need to *remove* the namespace for a
      resource, set the namespace to a blank String.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be underscored and not dashed.
  """

  alias JSONAPI.{Config, Document, Paginator, Resource}
  alias Plug.Conn

  @type t :: module()
  @type options :: keyword()
  @type data :: Resource.t() | [Resource.t()]

  @callback id(Resource.t()) :: Resource.id()
  @callback attributes :: [Resource.field()]
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback namespace :: String.t()
  @callback path :: String.t()
  @callback relationships :: [{Resource.field(), t()}]
  @callback type :: Resource.type()
  @callback url_for(Resource.t(), Conn.t() | nil) :: String.t()

  defmacro __using__(opts \\ []) do
    {resource, opts} = Keyword.pop(opts, :resource)
    {namespace, opts} = Keyword.pop(opts, :namespace)
    {path, opts} = Keyword.pop(opts, :path)
    {paginator, _opts} = Keyword.pop(opts, :paginator)

    quote do
      alias JSONAPI.{Document, Resource, View}

      @behaviour View

      @resource struct(unquote(resource))
      @namespace unquote(namespace)
      @path unquote(path)
      @paginator unquote(paginator)

      @impl View
      def id(resource), do: Resource.id(resource)

      @impl View
      def attributes, do: Resource.attributes(@resource)

      @impl View
      def links(_resource, _conn), do: %{}

      @impl View
      def meta(_resource, _conn), do: nil

      @impl View
      if @namespace do
        def namespace, do: @namespace
      else
        def namespace, do: Application.get_env(:jsonapi, :namespace, "")
      end

      @impl View
      def path, do: @path

      @impl View
      def relationships,
        do: Enum.concat(Resource.has_one(@resource), Resource.has_many(@resource))

      @impl View
      def type, do: Resource.type(@resource)

      @impl View
      def url_for(resource, conn),
        do: View.url_for(__MODULE__, resource, conn)

      defoverridable View
 
      def index(models, conn, _params, meta \\ nil, options \\ []),
        do: Serializer.serialize(__MODULE__, models, conn, meta, options)
 
      def show(model, conn, _params, meta \\ nil, options \\ []),
        do: Serializer.serialize(__MODULE__, model, conn, meta, options)

      def index(data, conn, _params, meta \\ nil, options \\ []),
        do: Document.serialize(__MODULE__, data, conn, meta, options)

      def show(data, conn, _params, meta \\ nil, options \\ []),
        do: Document.serialize(__MODULE__, data, conn, meta, options)

      if @paginator do
        def pagination_links(resource, conn, page, options),
          do: View.pagination_links(__MODULE__, resource, conn, page, @paginator, options)
      else
        def pagination_links(resource, conn, page, options),
          do:
            View.pagination_links(
              __MODULE__,
              resource,
              conn,
              page,
              Application.get_env(:jsonapi, :paginator),
              options
            )
      end

      if Code.ensure_loaded?(Phoenix) do
        def render("show.json", %{data: resource, conn: conn, meta: meta}),
          do: Document.serialize(__MODULE__, resource, conn, meta)

        def render("show.json", %{data: resource, conn: conn}),
          do: Document.serialize(__MODULE__, resource, conn)

        def render("index.json", %{data: resource, conn: conn, meta: meta}),
          do: Document.serialize(__MODULE__, resource, conn, meta)

        def render("index.json", %{data: resource, conn: conn}),
          do: Document.serialize(__MODULE__, resource, conn)
      else
        raise ArgumentError,
              "Attempted to call function that depends on Phoenix. " <>
                "Make sure Phoenix is part of your dependencies"
      end
    end
  end

  @spec attributes(t(), Resource.t(), Conn.t() | nil) :: %{
          Resource.field() => Document.value()
        }
  def attributes(view, resource, conn) do
    view
    |> visible_fields(conn)
    |> Enum.reduce(%{}, fn field, attributes ->
      value =
        if function_exported?(view, field, 2) do
          apply(view, field, [resource, conn])
        else
          Map.get(resource, field)
        end

      Map.put(attributes, field, value)
    end)
  end

  @spec pagination_links(
          t(),
          [Resource.t()],
          Conn.t() | nil,
          Paginator.params(),
          Paginator.t(),
          options()
        ) :: Document.links()
  def pagination_links(view, resources, conn, page, paginator, options) do
    if Code.ensure_loaded?(paginator) && function_exported?(paginator, :paginate, 5) do
      paginator.paginate(view, resources, conn, page, options)
    else
      %{}
    end
  end

  @spec url_for(t(), data() | nil, Conn.t() | nil) :: String.t()
  def url_for(view, resource, nil = _conn) when is_nil(resource) or is_list(resource),
    do: URI.to_string(%URI{path: Enum.join([view.namespace(), view.path() || view.type()], "/")})

  def url_for(view, resource, nil = _conn) do
    URI.to_string(%URI{
      path: Enum.join([view.namespace(), view.path() || view.type(), view.id(resource)], "/")
    })
  end

  def url_for(view, resource, %Conn{} = conn) when is_nil(resource) or is_list(resource) do
    URI.to_string(%URI{
      scheme: scheme(conn),
      host: host(conn),
      path: Enum.join([view.namespace(), view.path() || view.type()], "/")
    })
  end

  def url_for(view, resource, %Conn{} = conn) do
    URI.to_string(%URI{
      scheme: scheme(conn),
      host: host(conn),
      path: Enum.join([view.namespace(), view.path() || view.type(), view.id(resource)], "/")
    })
  end

  @spec url_for_relationship(t(), Resource.t(), Conn.t() | nil, Resource.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end

  @spec url_for_pagination(
          t(),
          [Resource.t()],
          Conn.t() | nil,
          Paginator.params() | nil
        ) ::
          String.t()
  def url_for_pagination(
        view,
        resources,
        %Conn{query_params: query_params} = conn,
        nil = _pagination_params
      ) do
    query =
      query_params
      |> to_list_of_query_string_components()
      |> URI.encode_query()

    prepare_url(view, resources, conn, query)
  end

  def url_for_pagination(
        view,
        resources,
        %Conn{query_params: query_params} = conn,
        pagination_params
      ) do
    query_params = Map.put(query_params, "page", pagination_params)

    url_for_pagination(view, resources, %Conn{conn | query_params: query_params}, nil)
  end

  defp prepare_url(view, resources, conn, "" = _query), do: url_for(view, resources, conn)

  defp prepare_url(view, resources, conn, query) do
    view
    |> url_for(resources, conn)
    |> URI.parse()
    |> struct(query: query)
    |> URI.to_string()
  end

  @spec visible_fields(t(), Conn.t() | nil) :: [Resource.field()]
  def visible_fields(view, conn) do
    view
    |> requested_fields_for_type(conn)
    |> net_fields_for_type(view.attributes())
  end

  defp net_fields_for_type(requested_fields, fields) when requested_fields in [nil, %{}],
    do: fields

  defp net_fields_for_type(requested_fields, fields) do
    fields
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(requested_fields))
    |> MapSet.to_list()
  end

  defp requested_fields_for_type(view, %Conn{assigns: %{jsonapi_query: %Config{fields: fields}}}),
    do: fields[view.type()]

  defp requested_fields_for_type(_view, _conn), do: nil

  defp host(%Conn{host: host}),
    do: Application.get_env(:jsonapi, :host, host)

  defp scheme(%Conn{scheme: scheme}),
    do: Application.get_env(:jsonapi, :scheme, to_string(scheme))

  def to_list_of_query_string_components(map) when is_map(map) do
    Enum.flat_map(map, &do_to_list_of_query_string_components/1)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_list(value) do
    to_list_of_two_elem_tuple(key, value)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_map(value) do
    Enum.flat_map(value, fn {k, v} -> to_list_of_two_elem_tuple("#{key}[#{k}]", v) end)
  end

  defp do_to_list_of_query_string_components({key, value}),
    do: to_list_of_two_elem_tuple(key, value)

  defp to_list_of_two_elem_tuple(key, value) when is_list(value) do
    Enum.map(value, &{"#{key}[]", &1})
  end

  defp to_list_of_two_elem_tuple(key, value) do
    [{key, value}]
  end
end
