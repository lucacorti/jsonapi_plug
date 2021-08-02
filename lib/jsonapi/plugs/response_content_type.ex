defmodule JSONAPI.ResponseContentType do
  @moduledoc """
  Simply add this plug to your endpoint or your router :api pipeline and it will
  ensure you return the correct response type.
  """

  @behaviour Plug

  alias Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{} = conn, _opts) do
    Conn.register_before_send(conn, &Conn.put_resp_content_type(&1, JSONAPI.mime_type()))
  end
end
