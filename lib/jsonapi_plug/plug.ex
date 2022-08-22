defmodule JSONAPIPlug.Plug do
  @moduledoc """
  Implements validation and parsing of `JSON:API` 1.0 requests

  This plug handles the standard `JSON:API` request body and query parameters
  (`fields`, `filter`, `include`, `page` and `sort`).

  # Usage

  To enable request deserialization add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.MyView
  ```

  If your connection receives a vali `JSON:API` request this plug will parse it into a
  `JSONAPIPlug` struct that will be stored in the `Plug.Conn` private assign `:jsonapi_plug`.
  The final output will look similar to the following:

  ```
  %Plug.Conn{
    ...
    body_params: %{...},
    params: %{"data" => ...},
    private: %{
      ...
      jsonapi_plug: %JSONAPIPlug{
        api: MyApp.API,
        document: %JSONAPIPlug.Document{...},
        fields: ..., # Defaults to a map of attributes by type.
        filter: ..., # Defaults to the query parameter value.
        include: ..., # Defaults to Ecto preload format.
        page: ..., # Defaults to the query parameter value.
        sort: ..., # Defaults to Ecto order_by format.
        view: MyApp.MyView
      }
      ...
    }
    ...
  }
  ```

  You can then use the contents of the struct to load data and generate responses.

  # Customizing default behaviour

  ## Body parameters

  By default, body parameters are transformed into a format that is easily used with
  `Ecto.Changeset` and `Ecto.Repo` to perform inserts/updates. However, you can transform
  the `JSON:API` data in any format you want by writing your own module adopting the
  `JSONAPIPlug.Normalizer` behaviour and configuring it through `JSONAPIPlug.API` configuration.

  ## Query parameters

  The `fields` and `include` query parameters format is defined by the `JSON:API` specification.
  The default implementation accepts the specification format and converts it to data usable as
  `select` and `preload` options to `Ecto.Repo` functions.

  The `sort` query parameter format is not defined, however the specification suggests to use a
  format for encoding sorting by attribute names with an optional `-` prefix to invert ordering
  direction. The default implementation accepts the suggested format and converts it to data usable
  as `order_by` arguments to Ecto queries.

  The `filter` and `page` query parameters format is not defined by the JSON:API specification,
  therefore the default implementation just copies the value of the query parameters in `JSONAPIPlug`.

  You can transform data in any format you want for any of these parameters by implementing a module
  adopting the `JSONAPIPlug.QueryParser` behaviour and configuring it through `JSONAPIPlug.API` configuration.
  """

  @options_schema NimbleOptions.new!(
                    api: [
                      doc: "A module use-ing `JSONAPIPlug.API` to provide configuration",
                      type: :atom,
                      required: true
                    ],
                    view: [
                      doc: "The `JSONAPIPlug.View` used to parse the request.",
                      type: :atom,
                      required: true
                    ]
                  )

  @typedoc """
  Options:
  #{NimbleOptions.docs(@options_schema)}
  """
  @type options :: keyword()

  use Plug.Builder

  plug :config_request, builder_opts()
  plug JSONAPIPlug.Plug.ContentTypeNegotiation
  plug JSONAPIPlug.Plug.FormatRequired
  plug JSONAPIPlug.Plug.IdRequired
  plug JSONAPIPlug.Plug.ResponseContentType
  plug JSONAPIPlug.Plug.QueryParam, :fields
  plug JSONAPIPlug.Plug.QueryParam, :filter
  plug JSONAPIPlug.Plug.QueryParam, :include
  plug JSONAPIPlug.Plug.QueryParam, :page
  plug JSONAPIPlug.Plug.QueryParam, :sort
  plug JSONAPIPlug.Plug.Document
  plug JSONAPIPlug.Plug.Params

  @doc false
  def config_request(conn, options) do
    NimbleOptions.validate!(options, @options_schema)

    {api, options} = Keyword.pop(options, :api)
    {view, _options} = Keyword.pop(options, :view)

    conn
    |> fetch_query_params()
    |> put_private(:jsonapi_plug, %JSONAPIPlug{api: api, view: view})
  end
end
