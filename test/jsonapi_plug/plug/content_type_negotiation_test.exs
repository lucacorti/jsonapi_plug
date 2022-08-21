defmodule JSONAPIPlug.Plug.ContentTypeNegotiationTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Plug.ContentTypeNegotiation
  alias Plug.Conn

  test "passes request through" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if no content-type or accept header" do
    conn =
      conn(:post, "/example", "")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only content-type header" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only accept header" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("accept", JSONAPIPlug.mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if multiple accept header" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct content-type header is last" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct accept header is last" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if content-type header contains other media type" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "text/html")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params (multiple)" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params with correct accept header" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if accept header contains other media type params" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}; charset=utf-8")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "halts and returns an error if all accept header media types contain media type params with no content-type" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "halts and returns an error if all accept header media types contain media type params" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "returned error has correct content type" do
    conn =
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert Conn.get_resp_header(conn, "content-type") == [JSONAPIPlug.mime_type()]
  end
end
