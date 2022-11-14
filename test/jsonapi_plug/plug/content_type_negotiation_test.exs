defmodule JSONAPIPlug.Plug.ContentTypeNegotiationTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidHeader
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
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "text/html")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params (multiple)" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "content-type",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if content-type header contains other media type params with correct accept header" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", "#{JSONAPIPlug.mime_type()}; version=1.0")
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if accept header contains other media type params" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header("accept", "#{JSONAPIPlug.mime_type()}; charset=utf-8")
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if all accept header media types contain media type params with no content-type" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end

  test "halts and returns an error if all accept header media types contain media type params" do
    assert_raise InvalidHeader, fn ->
      conn(:post, "/example", "")
      |> Conn.put_req_header("content-type", JSONAPIPlug.mime_type())
      |> Conn.put_req_header(
        "accept",
        "#{JSONAPIPlug.mime_type()}; version=1.0, #{JSONAPIPlug.mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])
    end
  end
end
