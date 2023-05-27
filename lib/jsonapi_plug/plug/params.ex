defmodule JSONAPIPlug.Plug.Params do
  @moduledoc """
  Plug for parsing the JSON:API Document in requests

  It parses the `JSON:API` document in the request body to a `JSONAPIPlug.Document` struct,
  notmalizes it and stores params in the `Plug.Conn` private assigns for later use.
  """

  alias JSONAPIPlug.{Document, Resource}

  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{body_params: %Conn.Unfetched{aspect: :body_params}}, _opts) do
    raise "Body unfetched when trying to parse JSON:API Document"
  end

  def call(
        %Conn{body_params: body_params, private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} =
          conn,
        _opts
      ) do
    body_params =
      body_params
      |> Document.parse()
      |> Resource.to_params(jsonapi_plug.resource, conn)

    Conn.put_private(conn, :jsonapi_plug, %JSONAPIPlug{jsonapi_plug | params: body_params})
  end
end
