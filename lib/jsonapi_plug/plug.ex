defmodule JSONAPIPlug.Plug do
  @moduledoc """
  Implements validation and parsing of `JSON:API` requests

  This plug handles the specification defined `JSON:API` request body and query parameters
  (`fields`, `filter`, `include`, `page` and `sort`).

  ## Usage

  Add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.MyView
  ```

  If your connection receives a valid `JSON:API` request this plug will parse it into a
  `JSONAPIPlug` struct that will be stored in the `Plug.Conn` private assign `:jsonapi_plug`.
  The final `Plug.Conn` struct will look similar to the following:

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
        fields: ..., # Defaults to a map of field names by type.
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

  You can then use the contents of the struct to load data and call `JSONAPIPlug.View.render/5` or the
  render function generated by `use JSONAPIPlug.View` to generate responses and render them.

  ## Customizing default behaviour

  ### Body parameters

  By default, body parameters are transformed into a format that is compatible with attrs for
  `Ecto.Changeset` to perform inserts/updates of `Ecto.Schema` modules. However, you can transform
  the `JSON:API` document in any format you want by writing your own module adopting the
  `JSONAPIPlug.Normalizer` behaviour and configuring it through `JSONAPIPlug.API` configuration.

  ### Query parameters

  The `JSON:API` `fields` and `include` query parameters format is defined by the specification.
  The default implementation accepts the specification format and converts it to data usable as
  `select` and `preload` options to `Ecto.Repo` functions.

  The `JSON:API` `sort` query parameter format is not defined, however the specification suggests
  to use a format for encoding sorting by attribute names with an optional `-` prefix to invert
  ordering direction. The default implementation accepts the suggested format and converts it to
  usable as `order_by` option to `Ecto.Repo` functions.

  The `JSON:API` `filter` and `page` query parameters format is not defined by the JSON:API specification,
  therefore the default implementation just copies the value of the query parameters in `JSONAPIPlug`.

  You can transform data in any format you want for any of these parameters by implementing a module
  adopting the `JSONAPIPlug.QueryParser` behaviour and configuring it through `JSONAPIPlug.API` configuration.
  """

  alias JSONAPIPlug.{Document, Exceptions}

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

  require Logger

  alias Plug.Conn.Status

  use Plug.Builder
  use Plug.ErrorHandler

  plug :config_request, builder_opts()
  plug JSONAPIPlug.Plug.ContentTypeNegotiation
  plug JSONAPIPlug.Plug.ResponseContentType
  plug JSONAPIPlug.Plug.QueryParam, :fields
  plug JSONAPIPlug.Plug.QueryParam, :filter
  plug JSONAPIPlug.Plug.QueryParam, :include
  plug JSONAPIPlug.Plug.QueryParam, :page
  plug JSONAPIPlug.Plug.QueryParam, :sort
  plug JSONAPIPlug.Plug.Document

  @doc false
  def config_request(conn, options) do
    options = NimbleOptions.validate!(options, @options_schema)
    api = Keyword.fetch!(options, :api)
    view = Keyword.fetch!(options, :view)

    conn
    |> fetch_query_params()
    |> put_private(:jsonapi_plug, %JSONAPIPlug{api: api, view: view})
  end

  @impl Plug.ErrorHandler
  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidDocument{} = exception, stack: _stack}
      ) do
    send_error(conn, :bad_request, %Document.ErrorObject{
      detail: "#{exception.message}. See #{exception.reference} for more information."
    })
  end

  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidHeader{} = exception, stack: _stack}
      ) do
    send_error(conn, exception.status, %Document.ErrorObject{
      detail: "#{exception.message}. See #{exception.reference} for more information.",
      source: %{pointer: "/header/" <> exception.header}
    })
  end

  def handle_errors(
        conn,
        %{kind: :error, reason: %Exceptions.InvalidQuery{} = exception, stack: _stack}
      ) do
    send_error(conn, :bad_request, %Document.ErrorObject{
      detail: exception.message,
      source: %{pointer: "/query/" <> exception.param}
    })
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack} = error) do
    Logger.debug("Unhandled exception: #{inspect(error)}")
    send_resp(conn, 500, "Something went wrong")
  end

  defp send_error(conn, code, error) do
    conn
    |> put_resp_content_type(JSONAPIPlug.mime_type())
    |> send_resp(
      code,
      Jason.encode!(%Document{
        errors: [
          %Document.ErrorObject{
            error
            | status: to_string(Status.code(code)),
              title: Status.reason_phrase(Status.code(code))
          }
        ]
      })
    )
    |> halt()
  end
end
