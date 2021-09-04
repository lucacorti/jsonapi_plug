defmodule JSONAPI.API do
  @moduledoc """
    JSON:API API Configuration

    You can define an API by either calling the use macro

    ```elixir
    defmodule MyAPI do
      use JSONAPI.API, namespace: "some-namespace", ...
    end
    ```

    or by implementing the `JSONAPI.API` behaviour

    ```elixir
    defmodule MyAPI do
      @behaviour JSONAPI.API

      @impl JSONAPI.API
      def namespace, do: "some-namespace"

      ...
    end
    ```

    All these options can be passed to the use macro or can be implemented/overridden as
    0-arity callbacks on your module:

      - **host** and **scheme**:
        If you pass these, values will override those taken by default from the pipeline `Plug.Conn`.
        E.g. if you want generated urls to point to `https://api.myhost.com` pass `host: "api.myhost.com", scheme: :https`
      - **namespace**:
        This optional setting can be used to configure a namespace for all routes in your API.
        E.g. if you want your car resources to live at "http://example.com/api/cars", pass `namespace: "api"
      - **inflection**:
      This option describes how your API's field names will be inflected.
      The available options are `:camelize` (default), `:dasherize` and `:underscore`
      [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/) recommends camelCase (e.g.
      `"favoriteColor": blue`).
      [JSON:API Spec (v1.0)](https://jsonapi.org/format/1.0/) recommends dasherizing (e.g.
      `"favorite-color": blue`).
      - **paginator**:
      `JSONAPI.Paginator` module for pagination. Defaults to `nil`.

    The API can also be overriden per route, see `JSONAPI.Request` documentation.
  """

  alias JSONAPI.{Paginator, Resource.Field}

  @type t :: module()

  @type host :: String.t()
  @type namespace :: String.t()
  @type scheme :: :http | :https
  @type version :: :"1.0"

  @callback host :: host() | nil
  @callback inflection :: Field.inflection() | nil
  @callback namespace :: namespace() | nil
  @callback paginator :: Paginator.t() | nil
  @callback scheme :: scheme() | nil
  @callback version :: version()

  defmacro __using__(options) do
    {host, options} = Keyword.pop(options, :host)
    {inflection, options} = Keyword.pop(options, :inflection)
    {namespace, options} = Keyword.pop(options, :namespace)
    {paginator, options} = Keyword.pop(options, :paginator)
    {scheme, options} = Keyword.pop(options, :scheme)
    {version, _options} = Keyword.pop(options, :version, :"1.0")

    quote do
      @behaviour JSONAPI.API

      @impl JSONAPI.API
      def host, do: unquote(host)

      @impl JSONAPI.API
      def inflection, do: unquote(inflection)

      @impl JSONAPI.API
      def namespace, do: unquote(namespace)

      @impl JSONAPI.API
      def paginator, do: unquote(paginator)

      @impl JSONAPI.API
      def scheme, do: unquote(scheme)

      @impl JSONAPI.API
      def version, do: unquote(version)
    end
  end
end
