defmodule JSONAPI.API do
  @moduledoc """
    JSON:API API Configuration

    You can define an API by calling `use JSONAPI.API` in your module

    ```elixir
    defmodule MyApp.MyAPI do
      use JSONAPI.API, otp_app: :my_app
    end
    ```

    API module behavior can be customized via your application configuration:

    ```elixir
    config :my_app, MyApp.MyAPI,
      namespace: "api",
      case: :dasherize
    ```
  """

  @options_schema [
    otp_app: [
      doc: "OTP application to use for API configuration.",
      type: :atom,
      required: true
    ]
  ]

  @config_schema [
    case: [
      doc:
        "This option controls how your API's field names will be cased. The current [JSON:API Spec (v1.0)](https://jsonapi.org/format/1.0/) recommends dasherizing (e.g. `\"favorite-color\": \"blue\"`), while the upcoming [JSON:API Spec (v1.1)](https://jsonapi.org/format/1.1/) recommends camelCase (e.g. `\"favoriteColor\": \"blue\"`)",
      type: {:in, [:camelize, :dasherize, :underscore]},
      required: false,
      default: :camelize
    ],
    host: [
      doc: "Hostname used for link generation instead of deriving it from the connection.",
      type: :string,
      required: false
    ],
    namespace: [
      doc:
        "Namespace for all resources in your API. if you want your resources to live under \".../api/v1\", pass `namespace: \"api/v1\"`.",
      type: :string,
      required: false
    ],
    pagination: [
      doc: "A module adopting the `JSONAPI.Pagination` behaviour for pagination.",
      type: :atom,
      required: false,
      default: nil
    ],
    port: [
      doc: "Port used for link generation instead of deriving it from the connection.",
      type: :pos_integer,
      required: false
    ],
    scheme: [
      doc: "Scheme used for link generation instead of deriving it from the connection.",
      type: {:in, [:http, :https]},
      required: false
    ],
    version: [
      doc: "[JSON:API](https://jsonapi.org) version advertised in the document",
      type: {:in, [:"1.0"]},
      required: false,
      default: :"1.0"
    ]
  ]

  alias JSONAPI.{Pagination, Resource}

  @type t :: module()

  @type config :: :case | :host | :namespace | :pagination | :port | :scheme | :version

  @type case :: Resource.case()
  @type host :: String.t()
  @type namespace :: String.t()
  @type pagination :: Pagination.t()
  @type http_port :: pos_integer()
  @type scheme :: :http | :https
  @type version :: :"1.0"

  defmacro __using__(options) do
    {otp_app, _options} =
      options
      |> NimbleOptions.validate!(@options_schema)
      |> Keyword.pop(:otp_app)

    quote do
      @__otp_app__ unquote(otp_app)
      def __otp_app__, do: @__otp_app__
    end
  end

  @doc """
  Retrieve a configuration parameter

  Retrieves an API configuration parameter value, with fallback to a default value
  in case the configuration parameter is not present.

  Available options are:
  #{NimbleOptions.docs(@config_schema)}
  """
  @spec get_config(t() | nil, config(), any()) :: any()
  def get_config(api, config, default \\ nil)

  def get_config(nil = _api, _config, default), do: default

  def get_config(api, config, default) do
    api
    |> get_all_config()
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(config, default)
  end

  defp get_all_config(api) do
    api.__otp_app__()
    |> Application.get_env(api, [])
  end
end
