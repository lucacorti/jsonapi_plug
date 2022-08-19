defmodule JSONAPI.Plug do
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
  plug JSONAPI.Plug, api: MyApp.API, view: MyApp.MyView
  ```

  If your connection receives a valid JSON:API request this plug will parse it into a `JSONAPI`
  struct that has all the validated and parsed fields and store it into the `Plug.Conn` private
  field `:jsonapi`. The final output will look similar to the following:

  ```
  %Plug.Conn{...
    private: %{...
      jsonapi: %JSONAPI{
        fields: %{"my-type" => [:id, :text], "comment" => [:id, :body],
        filter: %{"title" => "my title"} # Easily reduceable into ecto where clauses
        include: [comments: :user] # Easily insertable into a Repo.preload,
        page: %{
          limit: limit,
          offset: offset,
          page: page,
          size: size,
          cursor: cursor
        }},
        document: %JSONAPI.Document{...},
        sort: [desc: :created_at] # Easily insertable into an ecto order_by,
        view: MyApp.MyView
      }
    }
  }
  ```

  You can then use the contents of the struct to generate a response.
  """

  @options_schema NimbleOptions.new!(
                    api: [
                      doc: "A module use-ing `JSONAPI.API` to provide configuration",
                      type: :atom,
                      required: true
                    ],
                    view: [
                      doc: "The `JSONAPI.View` used to parse the request.",
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
  plug JSONAPI.Plug.ContentTypeNegotiation
  plug JSONAPI.Plug.FormatRequired
  plug JSONAPI.Plug.IdRequired
  plug JSONAPI.Plug.ResponseContentType
  plug JSONAPI.Plug.Fields
  plug JSONAPI.Plug.Filter
  plug JSONAPI.Plug.Include
  plug JSONAPI.Plug.Page
  plug JSONAPI.Plug.Sort
  plug JSONAPI.Plug.Document
  plug JSONAPI.Plug.Params

  @doc false
  def config_request(conn, options) do
    NimbleOptions.validate!(options, @options_schema)

    {api, options} = Keyword.pop(options, :api)
    {view, _options} = Keyword.pop(options, :view)

    conn
    |> fetch_query_params()
    |> put_private(:jsonapi, %JSONAPI{api: api, view: view})
  end
end
