defmodule JSONAPI.Plug.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type`
  and `accept` headers.

  The proper jsonapi.org content type is
  `application/vnd.api+json`. As per [the spec](http://jsonapi.org/format/#content-negotiation-servers)

  This plug does three things:

  1. Returns 415 unless the content-type header is correct.
  2. Returns 406 unless the accept header is correct.
  3. Registers a before send hook to set the content-type if not already set.
  """

  alias JSONAPI.{Document.ErrorObject, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"], do: conn

  def call(conn, _opts) do
    case {validate_header(conn, "content-type"), validate_header(conn, "accept")} do
      {true, true} ->
        conn

      {false, _} ->
        View.send_error(conn, 415, [%ErrorObject{}])

      {_, false} ->
        View.send_error(conn, 406, [%ErrorObject{}])
    end
  end

  defp validate_header(conn, header) do
    conn
    |> Conn.get_req_header(header)
    |> List.first(JSONAPI.mime_type())
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.member?(JSONAPI.mime_type())
  end
end
