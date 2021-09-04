defmodule JSONAPI.Plug.ResponseContentType do
  @moduledoc """
  Simply add this plug to your endpoint or your router :api pipeline and it will
  ensure you return the correct response type.
  """

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    Conn.register_before_send(conn, &Conn.put_resp_content_type(&1, JSONAPI.mime_type()))
  end
end
