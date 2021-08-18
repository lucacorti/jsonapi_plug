defmodule JSONAPI.FormatRequired do
  @moduledoc """
  Enforces the JSONAPI format of {"data" => {"attributes" => ...}} for request bodies
  """

  alias JSONAPI.ErrorView
  alias Plug.Conn

  # Cf. https://jsonapi.org/format/#crud-updating-to-many-relationships
  @update_has_many_relationships_methods ~w[DELETE PATCH POST]

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ~w[DELETE GET HEAD], do: conn

  def call(%{method: "POST", params: %{"data" => %{"type" => _}}} = conn, _), do: conn

  def call(%{method: method, params: %{"data" => [%{"type" => _} | _]}} = conn, _)
      when method in @update_has_many_relationships_methods do
    if String.contains?(conn.request_path, "relationships") do
      conn
    else
      ErrorView.send_error(conn, ErrorView.to_many_relationships_payload_for_standard_endpoint())
    end
  end

  def call(%Conn{params: %{"data" => %{"type" => _, "id" => _}}} = conn, _), do: conn

  def call(%Conn{method: "PATCH", params: %{"data" => %{"attributes" => _, "type" => _}}} = conn, _),
   do: ErrorView.send_error(conn, ErrorView.missing_data_id_param())

  def call(%Conn{method: "PATCH", params: %{"data" => %{"attributes" => _, "id" => _}}} = conn, _),
     do: ErrorView.send_error(conn, ErrorView.missing_data_type_param())

  def call(%Conn{params: %{"data" => %{"attributes" => _}}} = conn, _),
    do: ErrorView.send_error(conn, ErrorView.missing_data_type_param())

  def call(%{params: %{"data" => _}} = conn, _),
    do: ErrorView.send_error(conn, ErrorView.missing_data_attributes_param())

  def call(conn, _), do: ErrorView.send_error(conn, ErrorView.missing_data_param())
end
