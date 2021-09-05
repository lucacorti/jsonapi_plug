defmodule JSONAPI.Plug.ResponseContentTypeTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.Plug.ResponseContentType

  test "sets response content type" do
    conn =
      :get
      |> conn("/example", "")
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "content-type") == ["#{JSONAPI.mime_type()}; charset=utf-8"]
  end
end
