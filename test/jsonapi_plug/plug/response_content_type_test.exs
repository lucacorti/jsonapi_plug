defmodule JSONAPIPlug.Plug.ResponseContentTypeTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.Plug.ResponseContentType

  test "sets response content type" do
    conn =
      conn(:get, "/example", "")
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "content-type") == ["#{JSONAPIPlug.mime_type()}; charset=utf-8"]
  end
end
