defmodule JSONAPI.API do
  @moduledoc """
    JSON:API API Configuration

    You can define an API by either calling JSONAPI.API use macro

    ```elixir
    defmodule MyApp.MyAPI do
      use JSONAPI.API, otp_app: :my_app
    end
    ```

    API module behavior can be customized via your application configuration:

    ```elixir
    config :my_app, MyApp.MyAPI,
      inflection: :dasherize
    ```

    Available options:
    - **host**

        Hostname used for link generation

      - Type: `t:host/0`
      - Default: current `Plug.Conn` connection host
      - E.g. if you want generated urls to point `...://myhost.com` pass `host: "myhost.com"`

    - **scheme**

        Scheme used for link generation

        - Type: `t:scheme/0`
        - Default: current `Plug.Conn` connection scheme
        - E.g. if you want generated urls to point to `https://...` pass `scheme: :https`

    - **namespace**

        Namespace for all resources in your API.

      - Type: `t:namespace/0`
      - Default: `none`, no namespace applied
      - E.g. if you want your resources to live under ".../api/v1", pass `namespace: "api/v1"`

    - **inflection**

        This option describes how your API's field names will be inflected.

        The current [JSON:API Spec (v1.0)](https://jsonapi.org/format/1.0/) recommends dasherizing (e.g.
      `"favorite-color": "blue"`),
        while the upcoming [JSON:API Spec (v1.1)](https://jsonapi.org/format/1.1/) recommends camelCase (e.g.
      `"favoriteColor": "blue"`)

        - Type: `t:inflection/0`
        - Default: `:camelize`
        - E.g. if you want your resources field names to be dasherized, pass `inflection: :dasherize`

    - **paginator**

        `JSONAPI.Paginator` module for pagination.

        - Type: `t:paginator/0`
        - Default: `nil`, no pagination links are generated

    - **version**

        [JSON:API](https://jsonapi.org) version serialized in the top level `JSONAPI.Document.JSONAPIObject`

        - Type: `t:version/0`
        - Default: `:"1.0"`

    The API module can be overriden per plug/controller, see `JSONAPI.Plug.Request` for the details.
  """

  alias JSONAPI.{Paginator, Resource}

  @type t :: module()

  @type config :: :host | :namespace | :paginator | :scheme | :version

  @type host :: String.t()
  @type inflection :: Resource.inflection()
  @type namespace :: String.t()
  @type paginator :: Paginator.t()
  @type scheme :: :http | :https
  @type version :: :"1.0"

  defmacro __using__(options) do
    {otp_app, _options} = Keyword.pop(options, :otp_app)

    unless not is_nil(otp_app) do
      raise "You must pass the :otp_app option to JSONAPI.API"
    end

    unless is_atom(otp_app) do
      raise "You must pass a module name to JSONAPI.API :otp_app option"
    end

    quote do
      @__otp_app__ unquote(otp_app)
      def __otp_app__, do: @__otp_app__
    end
  end

  @doc """
  Retrieve a configuration parameter

  Retrieves an API configuration parameter value, with fallback to a default value
  in case the configuration parameter is not present.
  """
  @spec get_config(t() | nil, config(), any()) :: any()
  def get_config(api, config, default \\ nil)

  def get_config(nil = _api, _config, default), do: default

  def get_config(api, config, default) do
    api.__otp_app__()
    |> Application.get_env(api, [])
    |> Keyword.get(config, default)
  end
end
