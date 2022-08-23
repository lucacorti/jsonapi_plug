defmodule JSONAPIPlug.API do
  @moduledoc """
    JSON:API API Configuration

    You can define an API by calling `use JSONAPIPlug.API` in your module

    ```elixir
    defmodule MyApp.API do
      use JSONAPIPlug.API, otp_app: :my_app
    end
    ```

    API module behavior can be customized via your application configuration:

    ```elixir
    config :my_app, MyApp.API,
      namespace: "api",
      case: :dasherize
    ```
  """

  alias JSONAPIPlug.Pagination

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
        "This option controls how your API's field names will be cased. The current [JSON:API Specification (v1.0)](https://jsonapi.org/format/1.0/) recommends dasherizing (e.g. `\"favorite-color\": \"blue\"`), while the upcoming [JSON:API Specification (v1.1)](https://jsonapi.org/format/1.1/) recommends camelCase (e.g. `\"favoriteColor\": \"blue\"`)",
      type: {:in, [:camelize, :dasherize, :underscore]},
      default: :camelize
    ],
    host: [
      doc: "Hostname used for link generation instead of deriving it from the connection.",
      type: :string
    ],
    namespace: [
      doc:
        "Namespace for all resources in your API. if you want your resources to live under \".../api/v1\", pass `namespace: \"api/v1\"`.",
      type: :string
    ],
    normalizer: [
      doc: "Normalizer for transformation of `JSON:API` document to and from user data",
      type: :atom,
      default: JSONAPIPlug.Normalizer.Ecto
    ],
    query_parsers: [
      doc: "Parsers for transformation of `JSON:API` request query parameters to user data",
      type: :keyword_list,
      keys: [
        fields: [doc: "Fields", type: :atom, default: JSONAPIPlug.QueryParser.Ecto.Fields],
        filter: [doc: "Filter", type: :atom, default: JSONAPIPlug.QueryParser.Filter],
        include: [doc: "Include", type: :atom, default: JSONAPIPlug.QueryParser.Ecto.Include],
        page: [doc: "Page", type: :atom, default: JSONAPIPlug.QueryParser.Page],
        sort: [doc: "Sort", type: :atom, default: JSONAPIPlug.QueryParser.Ecto.Sort]
      ],
      default: [
        fields: JSONAPIPlug.QueryParser.Ecto.Fields,
        filter: JSONAPIPlug.QueryParser.Filter,
        include: JSONAPIPlug.QueryParser.Ecto.Include,
        page: JSONAPIPlug.QueryParser.Page,
        sort: JSONAPIPlug.QueryParser.Ecto.Sort
      ]
    ],
    pagination: [
      doc: "A module adopting the `JSONAPIPlug.Pagination` behaviour for pagination.",
      type: :atom,
      default: nil
    ],
    port: [
      doc: "Port used for link generation instead of deriving it from the connection.",
      type: :pos_integer
    ],
    scheme: [
      doc: "Scheme used for link generation instead of deriving it from the connection.",
      type: {:in, [:http, :https]}
    ],
    version: [
      doc: "`JSON:API` version advertised in the document",
      type: {:in, [:"1.0"]},
      default: :"1.0"
    ]
  ]

  @type t :: module()

  @type case :: JSONAPIPlug.case()
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
      @doc false
      def __otp_app__, do: unquote(otp_app)
    end
  end

  @doc """
  Retrieve a configuration parameter

  Retrieves an API configuration parameter value, with fallback to a default value
  in case the configuration parameter is not present.

  Available options are:
  #{NimbleOptions.docs(@config_schema)}
  """
  @spec get_config(t() | nil, [atom()], any()) :: any()
  def get_config(api, path, default \\ nil)

  def get_config(nil = _api, _path, default), do: default

  def get_config(api, path, default) do
    api
    |> get_all_config()
    |> NimbleOptions.validate!(@config_schema)
    |> get_in(path) || default
  end

  defp get_all_config(api) do
    api.__otp_app__()
    |> Application.get_env(api, [])
  end
end
