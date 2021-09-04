defmodule JSONAPI.Plug.IdRequired do
  @moduledoc """
  Ensure that the URL id matches the id in the request body and is a string
  """

  alias JSONAPI.{Document.ErrorObject, View}
  alias Plug.Conn

  @crud_message "Check out http://jsonapi.org/format/#crud for more info."

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD", "POST"],
    do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => id}} = conn, _) when is_binary(id),
    do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}}} = conn, _) when not is_binary(id) do
    View.send_error(conn, 422, [
      %ErrorObject{
        detail: @crud_message,
        source: %{pointer: "/data/id"},
        title: "Malformed id in data parameter"
      }
    ])
  end

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => _id}} = conn, _) when is_binary(id) do
    View.send_error(conn, 409, [
      %ErrorObject{
        detail: "The id in the url must match the id at '/data/id'. " <> @crud_message,
        source: %{pointer: "/data/id"},
        title: "Mismatched id parameter"
      }
    ])
  end

  def call(%Conn{params: %{"id" => _id}} = conn, _) do
    View.send_error(conn, 400, [
      %ErrorObject{
        detail: @crud_message,
        source: %{pointer: "/data/id"},
        title: "Missing id in data parameter"
      }
    ])
  end

  def call(conn, _), do: conn
end
