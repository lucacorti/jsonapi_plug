defmodule JSONAPIPlug.Plug.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type` and `accept` headers.

  The proper jsonapi.org content type is `application/vnd.api+json` as per
  [the specification](http://jsonapi.org/format/#content-negotiation-servers).
  """

  alias JSONAPIPlug.{Document.ErrorObject, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"],
    do: conn

  def call(conn, _opts) do
    case {validate_header(conn, "content-type"), validate_header(conn, "accept")} do
      {true, true} ->
        conn

      {false, _} ->
        View.send_error(conn, :unsupported_media_type, [
          %ErrorObject{
            detail:
              "The 'content-type' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()}).\nCheck out https://jsonapi.org/format/#content-negotiation.",
            source: %{pointer: "/headers/content-type"}
          }
        ])

      {_, false} ->
        View.send_error(conn, :not_acceptable, [
          %ErrorObject{
            detail:
              "The 'accept' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()}).\nCheck out https://jsonapi.org/format/#content-negotiation.",
            source: %{pointer: "/headers/accept"}
          }
        ])
    end
  end

  defp validate_header(conn, header) do
    value =
      conn
      |> Conn.get_req_header(header)
      |> List.first()

    (value || JSONAPIPlug.mime_type())
    |> String.split(",", trim: true)
    |> Enum.member?(JSONAPIPlug.mime_type())
  end
end
