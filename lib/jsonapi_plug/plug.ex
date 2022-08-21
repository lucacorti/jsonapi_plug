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
  format you want by writing your own module adopting the `JSONAPIPlug.Normalizer` behaviour:

  ```elixir
  defmodule MyApp.API.Normalizer
    ...

    @behaviour JSONAPIPlug.Normalizer

    # Transforms requests from `JSONAPIPlug.Document` to user data
    @impl JSONAPIPlug.Normalizer
    def denormalize(document, view, conn) do
      ...
    end

    # Transforms responsens from user data to `JSONAPIPlug.Document`
    @impl JSONAPIPlug.Normalizer
    def normalize(view, conn, data, meta, options) do
      ...
    end

    ...
  end
  ```

  and by configuring in in your api configuration:

  ```elixir
  config :my_app, MyAPP.API, normalizer: MyAPP.API.Normalizer
  ```

  The normalizer takes the preparsed `JSONAPI.Document` as input and its return value
  replaces the conn `body_params` and is also placed in the conn `params` under a "data" key
  for use in your application logic.

  You can return an error during parsing by raising `JSONAPIPlug.Exceptions.InvalidDocument` at
  any point in your normalizer code.

  ## Filter, Page and Sort query parameters

  The `sort` query parameter format is not mandated by the spec, although it suggests to use a
  specific format for encoding sorting by attribute names with a prefixed '-' to invert ordering
  direction.

  The default implementation takes the suggested format and converts it to a format compatible
   with order_by arguments to Ecto queries.

  You customize the default behaviour by implementing a module adopting the `JSONAPIPlug.QueryParser`
  behaviour for your sort format:

  ```elixir
  defmodule MyApp.API.QueryParsers.Sort do
    ...
    @behaviour JSONAPIPlug.QueryParser

    # Transforms the query parameter value to a user defined format
    @impl JSONAPIPlug.QueryParser
    def parse(jsonapi_plug, sort) do
      ...
    end
  end
  ```

  and configure it in your API configuration under the `parsers` key.

  ```elixir
  config :my_app, MyApp.API,
    parsers: [
      sort: MyApp.API.QueryParsers.Sort
    ]
  ```

  The `filter` and `page` query parameters format is not specified by the JSON:API specification,
  therefore the default implementation just copies the value of the query parameter.

  Parsing can be customized, just like with sort, by implementing the `JSONAPIPlug.QueryParser`
  behaviour for your parameter format and configuring it in your API configuration under the `parsers` key.

  ```elixir
  config :my_app, MyApp.API,
    parsers: [
      filter: MyApp.API.QueryParser.Filter,
      page: MyApp.API.QueryParser.Page
    ]
  ```

  The parser takes the query paramter value and its return value is placed under the query parameter
  name in the `JSONAPIPlug` structure in the conn `private` assigns so that you can retrieve it and
  use it in your application logic.

  You can return an error by raising `JSONAPIPlug.Exceptions.InvalidQuery` at any point in your parser code.
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
