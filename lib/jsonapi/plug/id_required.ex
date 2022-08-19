defmodule JSONAPI.Plug.IdRequired do
  @moduledoc """
  Ensure that the URL id matches the id in the request body and is a string
  """

  alias JSONAPI.{Document.ErrorObject, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{method: method} = conn, _opts)
      when method in ["DELETE", "GET", "HEAD", "POST"],
      do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => id}} = conn, _opts)
      when is_binary(id) and byte_size(id) > 0,
      do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}}} = conn, _opts)
      when not is_binary(id) or byte_size(id) < 0 do
    View.send_error(conn, :unprocessable_entity, [
      %ErrorObject{
        detail:
          "Malformed id in data parameter: id must be a string, Check out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/id"}
      }
    ])
  end

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => _id}} = conn, _opts)
      when is_binary(id) and byte_size(id) > 0 do
    View.send_error(conn, :conflict, [
      %ErrorObject{
        detail:
          "Mismatched id parameter: the id in the url must match the id at '/data/id'.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/id"}
      }
    ])
  end

  def call(%Conn{params: %{"id" => _id}} = conn, _opts) do
    View.send_error(conn, :bad_request, [
      %ErrorObject{
        detail:
          "Missing id in data parameter.\nCheck out http://jsonapi.org/format/#crud for more info.",
        source: %{pointer: "/data/id"}
      }
    ])
  end

  def call(conn, _opts), do: conn
end
