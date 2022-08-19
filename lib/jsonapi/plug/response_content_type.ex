defmodule JSONAPI.Plug.ResponseContentType do
  @moduledoc """
  Sets the JSONAPI mime type on responses.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts),
    do: Conn.register_before_send(conn, &Conn.put_resp_content_type(&1, JSONAPI.mime_type()))
end
