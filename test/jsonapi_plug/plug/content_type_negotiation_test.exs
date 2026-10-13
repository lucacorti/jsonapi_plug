defmodule JSONAPIPlug.Plug.ContentTypeNegotiationTest do
  use ExUnit.Case
  import Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidHeader
  alias JSONAPIPlug.Plug.ContentTypeNegotiation
  alias Plug.Conn

  # Helper to build a conn pre-loaded with a simulated jsonapi_plug config
  defp conn_with_config(method, path, body \\ "", extensions \\ []) do
    conn(method, path, body)
    |> Conn.put_private(:jsonapi_plug, %JSONAPIPlug{
      config: [extensions: extensions, profiles: []]
    })
  end

  test "passes request through" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if no content-type or accept header" do
    conn =
      conn_with_config(:post, "/example")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only content-type header" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only accept header" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if multiple accept header" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct content-type header is last" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct content-type header is last (invalid before valid)" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct accept header is last" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if content-type header contains other media type" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", "text/html")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params (multiple)" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params with correct accept header" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if accept header contains other media type params" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}; charset=utf-8")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if all accept header media types contain media type params with no content-type" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if all accept header media types contain media type params" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  # JSON:API 1.1 ext/profile parameter tests

  test "passes request through with ext parameter for supported extension" do
    ext_uri = "https://example.com/ext"

    conn =
      conn_with_config(:post, "/example", "", [ext_uri])
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; ext=\"#{ext_uri}\""
      )
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "raises 415 if content-type ext contains unsupported extension URI" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; ext=\"https://unknown.example.com/ext\""
      )
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])
    end
  end

  test "passes request through with profile parameter in content-type" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; profile=\"https://example.com/profile\""
      )
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "raises 406 when all accept entries have unsupported ext URIs" do
    assert_raise InvalidHeader, fn ->
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; ext=\"https://unknown.example.com/ext\""
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  test "passes request through with profile param only in accept header" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; profile=\"https://example.com/profile\""
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes if accept has mix of unsupported ext and plain JSON:API entries" do
    conn =
      conn_with_config(:post, "/example")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; ext=\"https://unknown.example.com/ext\", #{JSONAPIPlug.mime_type()}"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "GET requests skip content-type validation" do
    conn =
      conn_with_config(:get, "/example")
      |> Conn.put_req_header("content-type", "text/html")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end
end
