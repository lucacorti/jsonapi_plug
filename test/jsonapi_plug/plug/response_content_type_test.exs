defmodule JSONAPIPlug.Plug.ResponseContentTypeTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias JSONAPIPlug.Plug.ResponseContentType

  defp conn_with_config(extensions \\ [], profiles \\ []) do
    conn(:get, "/example", "")
    |> Plug.Conn.put_private(:jsonapi_plug, %JSONAPIPlug{
      config: [extensions: extensions, profiles: profiles]
    })
  end

  test "sets plain JSON:API response content type when no extensions or profiles" do
    conn =
      conn_with_config()
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "content-type") == ["#{JSONAPIPlug.mime_type()}; charset=utf-8"]
  end

  test "does not add Vary header when no extensions or profiles" do
    conn =
      conn_with_config()
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "vary") == []
  end

  test "sets content type with ext parameter when extensions configured" do
    ext_uri = "https://example.com/ext"

    conn =
      conn_with_config([ext_uri])
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    [content_type] = get_resp_header(conn, "content-type")
    assert String.contains?(content_type, "application/vnd.api+json")
    assert String.contains?(content_type, ~s(ext="#{ext_uri}"))
  end

  test "sets content type with profile parameter when profiles configured" do
    profile_uri = "https://example.com/profile"

    conn =
      conn_with_config([], [profile_uri])
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    [content_type] = get_resp_header(conn, "content-type")
    assert String.contains?(content_type, "application/vnd.api+json")
    assert String.contains?(content_type, ~s(profile="#{profile_uri}"))
  end

  test "adds Vary: Accept header when extensions are configured" do
    conn =
      conn_with_config(["https://example.com/ext"])
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "vary") == ["Accept"]
  end

  test "adds Vary: Accept header when profiles are configured" do
    conn =
      conn_with_config([], ["https://example.com/profile"])
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "vary") == ["Accept"]
  end

  test "does not overwrite existing Vary header set by an upstream plug" do
    conn =
      conn_with_config(["https://example.com/ext"])
      |> put_resp_header("vary", "Origin")
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    vary_values = get_resp_header(conn, "vary")
    vary_string = Enum.join(vary_values, ", ")
    assert String.contains?(vary_string, "Accept"), "Vary should contain Accept"

    assert String.contains?(vary_string, "Origin"),
           "Vary should contain Origin (must not be overwritten)"
  end

  test "does not override existing content-type header" do
    conn =
      conn_with_config()
      |> put_resp_content_type("text/plain")
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    [content_type] = get_resp_header(conn, "content-type")
    assert String.starts_with?(content_type, "text/plain")
  end
end
