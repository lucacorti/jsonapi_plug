defmodule JSONAPIPlug.API do
  @moduledoc """
    JSON:API API Configuration

    You can define an API by "use-ing" `JSONAPIPlug.API` in your API module:

    ```elixir
    defmodule MyApp.API do
      use JSONAPIPlug.API, otp_app: :my_app
    end
    ```

    API module configuration can be customized via your application configuration:

    ```elixir
    config :my_app, MyApp.API,
      namespace: "api",
      case: :dasherize
    ```

    See `t:options/0` for all available configuration options.
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
        "This option controls how your API's field names will be cased. The current [JSON:API Specification (v1.0)](https://jsonapi.org/format/1.0/) recommends dasherizing (e.g. `\"favorite-color\": \"blue\"`), while the upcoming [JSON:API Specification (v1.1)](https://jsonapi.org/format/1.1/) recommends camelCase (e.g. `\"favoriteColor\": \"blue\"`).",
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
      doc: "Normalizer for transformation of `JSON:API` document to and from user data.",
      type: :atom,
      default: JSONAPIPlug.Normalizer.Ecto
    ],
    query_parsers: [
      doc: "Parsers for transformation of `JSON:API` request query parameters to user data.",
      type: :keyword_list,
      keys: [
        fields: [
          doc: "Fields query parameter parser.",
          type: :atom,
          default: JSONAPIPlug.QueryParser.Ecto.Fields
        ],
        filter: [
          doc: "Filter query parameter parser.",
          type: :atom,
          default: JSONAPIPlug.QueryParser.Filter
        ],
        include: [
          doc: "Include query parameter parser.",
          type: :atom,
          default: JSONAPIPlug.QueryParser.Ecto.Include
        ],
        page: [
          doc: "Page query parameter parser.",
          type: :atom,
          default: JSONAPIPlug.QueryParser.Page
        ],
        sort: [
          doc: "Sort query parameter parser.",
          type: :atom,
          default: JSONAPIPlug.QueryParser.Ecto.Sort
        ]
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

  @typedoc """
  API configuration options:

  #{NimbleOptions.docs(@config_schema)}
  """
  @type options :: keyword()

  defmacro __using__(options) do
    otp_app =
      options
      |> NimbleOptions.validate!(@options_schema)
      |> Keyword.fetch!(:otp_app)

    quote do
      @doc false
      def __otp_app__, do: unquote(otp_app)
    end
  end

  @doc """
  Retrieve a configuration option

  Retrieves an API configuration option value, with fallback to a default value
  in case the configuration option is not present.
  """
  @spec get_config(t() | nil, [atom()], term()) :: term()
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
