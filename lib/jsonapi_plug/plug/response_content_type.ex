defmodule JSONAPIPlug.Plug.ResponseContentType do
  @moduledoc """
  Plug for setting the response content type

  Registers a before send function that sets the `JSON:API` content type on responses unless a response
  content type has already been set on the connection.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    Conn.register_before_send(
      conn,
      &set_content_type(&1, Conn.get_resp_header(&1, "content-type"))
    )
  end

  defp set_content_type(conn, []), do: Conn.put_resp_content_type(conn, JSONAPIPlug.mime_type())
  defp set_content_type(conn, _content_type), do: conn
end
