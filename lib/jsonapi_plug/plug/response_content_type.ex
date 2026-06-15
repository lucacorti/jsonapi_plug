defmodule JSONAPIPlug.Plug.ResponseContentType do
  @moduledoc """
  Plug for setting the response content type

  Registers a before send function that sets the `JSON:API` content type on responses unless a
  response content type has already been set on the connection.

  When the API is configured with `extensions` or `profiles`, the response `Content-Type` header
  will include the corresponding `ext` and/or `profile` media type parameters. A `Vary: Accept`
  header is also added in that case, as required by JSON:API 1.1.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    Conn.register_before_send(conn, &set_response_headers/1)
  end

  defp set_response_headers(conn) do
    conn
    |> set_content_type(Conn.get_resp_header(conn, "content-type"))
    |> set_vary()
  end

  defp set_content_type(conn, []) do
    mime = build_content_type(conn)
    Conn.put_resp_content_type(conn, mime)
  end

  defp set_content_type(conn, _content_type), do: conn

  defp set_vary(conn) do
    extensions = api_config(conn, :extensions)
    profiles = api_config(conn, :profiles)

    if extensions != [] or profiles != [] do
      Conn.prepend_resp_headers(conn, [{"vary", "Accept"}])
    else
      conn
    end
  end

  defp build_content_type(conn) do
    extensions = api_config(conn, :extensions)
    profiles = api_config(conn, :profiles)

    params =
      []
      |> add_param("ext", extensions)
      |> add_param("profile", profiles)

    case params do
      [] -> JSONAPIPlug.mime_type()
      _ -> "#{JSONAPIPlug.mime_type()}; #{Enum.join(params, "; ")}"
    end
  end

  defp add_param(params, _name, []), do: params

  defp add_param(params, name, uris) do
    params ++ ["#{name}=\"#{Enum.join(uris, " ")}\""]
  end

  defp api_config(conn, key) do
    case conn.private do
      %{jsonapi_plug: %JSONAPIPlug{config: config}} when not is_nil(config) ->
        config[key] || []

      _ ->
        []
    end
  end
end
