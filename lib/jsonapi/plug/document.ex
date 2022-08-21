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
  def call(%Conn{body_params: %Conn.Unfetched{aspect: :body_params}}, _opts) do
    raise "Body unfetched when trying to parse JSON:API Document"
  end

  def call(
        %Conn{body_params: body_params, private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | document: Document.deserialize(body_params)}
    )
  end
end
