defmodule JSONAPI.Plug.Document do
  @moduledoc """
  Plug for parsing the JSON:API Document body
  """

  alias JSONAPI.Document
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(
        %Conn{body_params: body_params, private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | document: parse_body(jsonapi, body_params)}
    )
  end

  defp parse_body(_jsonapi, %Conn.Unfetched{aspect: :body_params}) do
    raise "Body unfetched when trying to parse JSON:API Document"
  end

  defp parse_body(_jsonapi, body_params),
    do: Document.deserialize(body_params)
end
