defmodule JSONAPI.IdRequired do
  @moduledoc """
  Ensure that the URL id matches the id in the request body and is a string
  """

  alias JSONAPI.ErrorView
  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD", "POST"],
    do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => id}} = conn, _) when is_binary(id),
    do: conn

  def call(%Conn{params: %{"data" => %{"id" => id}}} = conn, _) when not is_binary(id),
    do: ErrorView.send_error(conn, ErrorView.malformed_id())

  def call(%Conn{params: %{"data" => %{"id" => id}, "id" => _id}} = conn, _) when is_binary(id),
    do: ErrorView.send_error(conn, ErrorView.mismatched_id())

  def call(%Conn{params: %{"id" => _id}} = conn, _),
    do: ErrorView.send_error(conn, ErrorView.missing_id())

  def call(conn, _), do: conn
end
