defmodule JSONAPIPlug.Plug.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type` and `accept` headers.

  The proper jsonapi.org content type is `application/vnd.api+json` as per
  [the specification](http://jsonapi.org/format/#content-negotiation-servers).
  """

  alias JSONAPIPlug.Exceptions.InvalidHeader
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
        raise InvalidHeader,
          status: :unsupported_content_type,
          message:
            "The 'content-type' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()})",
          reference: "https://jsonapi.org/format/#content-negotiation.",
          header: "content-type"

      {_, false} ->
        raise InvalidHeader,
          status: :not_acceptable,
          message:
            "The 'accept' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()})",
          reference: "https://jsonapi.org/format/#content-negotiation",
          header: "accept"
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
