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
    config :my_app, MyApp.API, namespace: "api"
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
    ]
  ]

  alias JSONAPIPlug.Document
  alias Plug.Conn

  @type t :: module()

  @callback links(Conn.t()) :: Document.links()
  @callback meta(Conn.t()) :: Document.meta()

  @typedoc """
  API configuration options:

  #{NimbleOptions.docs(@config_schema)}
  """
  @type options :: keyword()

  defmacro __using__(options) do
    options = NimbleOptions.validate!(options, @options_schema)

    quote do
      @doc false
      def __otp_app__, do: unquote(options[:otp_app])

      @behaviour JSONAPIPlug.API

      @impl JSONAPIPlug.API
      def links(_conn), do: %{}

      @impl JSONAPIPlug.API
      def meta(_conn), do: %{}

      defoverridable JSONAPIPlug.API
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
    config = :persistent_term.get(api, nil)

    if is_nil(config) do
      config =
        api.__otp_app__()
        |> Application.get_env(api, [])
        |> NimbleOptions.validate!(@config_schema)

      :persistent_term.put(api, config)
      get_in(config, path) || default
    else
      get_in(config, path) || default
    end
  end
end
