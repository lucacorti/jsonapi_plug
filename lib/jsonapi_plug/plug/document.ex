defmodule JSONAPIPlug.Plug.Document do
  @moduledoc """
  Plug for parsing the JSON:API Document in requests

  It parses the `JSON:API` document in the request body to a `JSOANAPIPlug.Document` struct
  and stores it in the `Plug.Conn` private assigns for later use by other plugs and application code.
  """

  alias JSONAPIPlug.Document
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
    Conn.put_private(
      conn,
      :jsonapi_plug,
      %JSONAPIPlug{jsonapi_plug | document: Document.deserialize(body_params)}
    )
  end
end
