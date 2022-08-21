defmodule JSONAPI.Plug.FormatRequired do
  @moduledoc """
  Enforces the JSONAPI format of {"data" => {"attributes" => ...}} for request bodies

  See the [spec](https://jsonapi.org/format/#crud-updating-to-many-relationships).
  """

  alias JSONAPI.{Document.ErrorObject, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"], do: conn

  def call(%{method: "POST", params: %{"data" => %{"type" => _}}} = conn, _opts), do: conn

  def call(%{method: method, params: %{"data" => [%{"type" => _} | _]}} = conn, _opts)
      when method in ["DELETE", "PATCH", "POST"] do
    if String.contains?(conn.request_path, "relationships") do
      conn
    else
      View.send_error(conn, :bad_request, [
        %ErrorObject{
          detail:
            "Data parameter has multiple Resource Identifier Objects for a non-relationship endpoint.\nCheck out https://jsonapi.org/format/#crud-updating-to-many-relationships for more info.",
          source: %{pointer: "/data"}
        }
      ])
    end
  end

  def call(%Conn{params: %{"data" => %{"type" => _, "id" => _}}} = conn, _opts), do: conn

  def call(
        %Conn{method: "PATCH", params: %{"data" => %{"attributes" => _, "type" => _}}} = conn,
        _opts
      ) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing id in data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/id"}
      }
    ])
  end

  def call(
        %Conn{method: "PATCH", params: %{"data" => %{"attributes" => _, "id" => _}}} = conn,
        _opts
      ) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing type in data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/type"}
      }
    ])
  end

  def call(%Conn{params: %{"data" => %{"attributes" => _}}} = conn, _opts) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing type in data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/type"}
      }
    ])
  end

  def call(%{params: %{"data" => _}} = conn, _opts) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing attributes in data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/attributes"}
      }
    ])
  end

  def call(conn, _opts) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data"}
      }
    ])
  end
end
