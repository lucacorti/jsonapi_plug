defmodule JSONAPI.Plug.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type` and `accept` headers.

  The proper jsonapi.org content type is `application/vnd.api+json` as per
  [the spec](http://jsonapi.org/format/#content-negotiation-servers)
  """

  alias JSONAPI.{Document.ErrorObject, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{method: method} = conn, _options) when method in ["DELETE", "GET", "HEAD"],
    do: conn

  def call(conn, _options) do
    case {validate_header(conn, "content-type"), validate_header(conn, "accept")} do
      {true, true} ->
        conn

      {false, _} ->
        View.send_error(conn, :unsupported_media_type, [%ErrorObject{}])

      {_, false} ->
        View.send_error(conn, :not_acceptable, [%ErrorObject{}])
    end
  end

  defp validate_header(conn, header) do
    value =
      conn
      |> Conn.get_req_header(header)
      |> List.first()

    (value || JSONAPI.mime_type())
    |> String.split(",", trim: true)
    |> Enum.member?(JSONAPI.mime_type())
  end
end
