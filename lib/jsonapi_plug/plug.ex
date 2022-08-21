defmodule JSONAPIPlug.Plug do
  @moduledoc """
  Implements parsing of JSON:API 1.0 requests.

  The purpose is to validate and encode incoming requests. This handles the request body document
  and query parameters for:

    * [sorts](http://jsonapi.org/format/#fetching-sorting)
    * [include](http://jsonapi.org/format/#fetching-includes)
    * [filtering](http://jsonapi.org/format/#fetching-filtering)
    * [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
    * [pagination](http://jsonapi.org/format/#fetching-pagination)

  To enable request deserialization add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.MyView
  ```

  If your connection receives a valid JSON:API request this plug will parse it into a `JSONAPIPlug`
  struct that has all the validated and parsed fields and store it into the `Plug.Conn` private
  field `:jsonapi_plug`. The final output will look similar to the following:

  ```
  %Plug.Conn{...
    private: %{...
      jsonapi_plug: %JSONAPIPlug{
        fields: %{"my-type" => [:id, :text], "comment" => [:id, :body]},
        filter: ... # Passed as is by default, can be customized via `JSONAPIPlug.QueryParser`
        include: [comments: [user: []]] # Easily insertable into a Repo.preload,
        page: ... # Passed as is by default, can be customized via `JSONAPIPlug.QueryParser`
        document: %JSONAPIPlug.Document{...},
        sort: [desc: :created_at] # Converted to Ecto order_by format by default, can be customized via `JSONAPIPlug.QueryParser`
        view: MyApp.MyView
      }
    }
  }
  ```

  # Customizing
  You can then use the contents of the struct to generate a response.
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
