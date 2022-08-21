defmodule JSONAPIPlug.Plug do
  @moduledoc """
  Implements validation and parsing of JSON:API 1.0 requests. This handles the
  JSON:API request body and query parameters for:

    - [sorts](http://jsonapi.org/format/#fetching-sorting)
    - [include](http://jsonapi.org/format/#fetching-includes)
    - [filter](http://jsonapi.org/format/#fetching-filtering)
    - [fields](https://jsonapi.org/format/#fetching-sparse-fieldsets)
    - [page](http://jsonapi.org/format/#fetching-pagination)

  # Usage

  To enable request deserialization add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.MyView
  ```

  If your connection receives a valid JSON:API request this plug will parse it into a
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
        fields: %{"my-type" => [:id, :text], "comment" => [:id, :body]},
        filter: ... # Passed as is by default, can be customized.
        include: [comments: [user: []]] # Easily useable with Ecto.Repo.preload,
        page: ... # Passed as is by default, can be customized.
        sort: [desc: :created_at] # Converted to Ecto order_by format by default, can be customized.
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
  Ecto Changeset to perform inserts/updates. However, you can transform the data in any
  format you want by writing your own module adopting the `JSONAPIPlug.Normalizer` behaviour.

  ## Filter, Page and Sort query parameters

  The `sort` query parameter format is not mandated, however the specification suggests to use a
  format for encoding sorting by attribute names with a prefixed '-' to invert ordering direction.
  The default implementation accepts the suggested format and converts it to data usable as
  `order_by` arguments to Ecto queries.

  The `filter` and `page` query parameters format is not defined by the JSON:API specification,
  therefore the default implementation just copies the value of the query parameters in `JSONAPIPlug`.

  Parsing can be customized by implementing the `JSONAPIPlug.QueryParser` behaviour.
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
  plug JSONAPIPlug.Plug.Fields
  plug JSONAPIPlug.Plug.QueryParam, :filter
  plug JSONAPIPlug.Plug.Include
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
