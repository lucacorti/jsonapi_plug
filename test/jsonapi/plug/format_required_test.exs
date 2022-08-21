defmodule JSONAPI.Plug.FormatRequiredTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.Plug.FormatRequired
  alias Plug.{Conn, Parsers}

  test "halts and returns an error for missing data param" do
    conn =
      conn(:post, "/example", Jason.encode!(%{}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  test "halts and returns an error for missing attributes in data param" do
    conn =
      conn(:post, "/example", Jason.encode!(%{data: %{}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/attributes"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  test "halts and returns an error for missing type in data param" do
    conn =
      conn(:post, "/example", Jason.encode!(%{data: %{attributes: %{}}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/type"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  test "does not halt if only type member is present on a post" do
    conn =
      conn(:post, "/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    refute conn.halted
  end

  test "halts and returns an error for missing id in data param on a patch" do
    conn =
      conn(:patch, "/example", Jason.encode!(%{data: %{attributes: %{}, type: "something"}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/id"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  test "halts and returns an error for missing type in data param on a patch" do
    conn =
      conn(:patch, "/example", Jason.encode!(%{data: %{attributes: %{}, id: "something"}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/type"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  test "does not halt if type and id members are present on a patch" do
    conn =
      conn(
        :patch,
        "/example",
        Jason.encode!(%{data: %{type: "something", id: "some-identifier"}})
      )
      |> call_plug

    refute conn.halted
  end

  test "halts with a multi-RIO payload to a non-relationship PATCH endpoint" do
    conn(:patch, "/example", Jason.encode!(%{data: [%{type: "something"}]}))
    |> call_plug
    |> assert_improper_use_of_multi_rio()
  end

  test "halts with a multi-RIO payload to a non-relationship POST endpoint" do
    conn(:post, "/example", Jason.encode!(%{data: [%{type: "something"}]}))
    |> call_plug
    |> assert_improper_use_of_multi_rio()
  end

  test "accepts a multi-RIO payload for relationship PATCH endpoints" do
    conn =
      conn(
        :patch,
        "/example/relationships/things",
        Jason.encode!(%{data: [%{type: "something"}]})
      )
      |> call_plug

    refute conn.halted
  end

  test "accepts a multi-RIO payload for relationship POST endpoints" do
    conn =
      conn(:post, "/example/relationships/things", Jason.encode!(%{data: [%{type: "something"}]}))
      |> call_plug

    refute conn.halted
  end

  test "passes request through" do
    conn =
      conn(:post, "/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    refute conn.halted
  end

  defp assert_improper_use_of_multi_rio(conn) do
    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data"},
             "status" => "400",
             "title" => "Bad Request"
           } = error
  end

  defp call_plug(conn) do
    parser_options = Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)

    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Parsers.call(parser_options)
    |> FormatRequired.call([])
  end
end
