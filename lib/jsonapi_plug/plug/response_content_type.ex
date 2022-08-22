defmodule JSONAPIPlug.Plug.ResponseContentType do
  @moduledoc """
  Plug for setting the response content type

  Registers a before send function that sets the `JSON:API` content type on responses.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts),
    do: Conn.register_before_send(conn, &Conn.put_resp_content_type(&1, JSONAPIPlug.mime_type()))
end
