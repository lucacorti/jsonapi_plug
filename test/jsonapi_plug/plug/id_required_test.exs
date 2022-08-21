defmodule JSONAPIPlug.Plug.IdRequiredTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Plug.IdRequired
  alias Plug.{Conn, Parsers}

  test "halts and returns an error if id attribute is missing" do
    conn =
      conn(:patch, "/example/1", Jason.encode!(%{data: %{}}))
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

  test "halts and returns an error if id attribute is not a string" do
    conn =
      conn(:patch, "/example/1", Jason.encode!(%{data: %{id: 1}}))
      |> call_plug

    assert conn.halted
    assert 422 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/id"},
             "status" => "422",
             "title" => "Unprocessable Entity"
           } = error
  end

  test "halts and returns an error if id attribute and url id are mismatched" do
    conn =
      conn(:patch, "/example/1", Jason.encode!(%{data: %{id: "2"}}))
      |> call_plug

    assert conn.halted
    assert 409 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/id"},
             "status" => "409",
             "title" => "Conflict"
           } = error
  end

  test "passes request through" do
    conn =
      conn(:patch, "/example/1", Jason.encode!(%{data: %{id: "1"}}))
      |> call_plug

    assert not conn.halted
  end

  defp call_plug(%{path_info: [_, id]} = conn) do
    parser_options = Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)

    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Map.put(:path_params, %{"id" => id})
    |> Parsers.call(parser_options)
    |> IdRequired.call([])
  end
end
