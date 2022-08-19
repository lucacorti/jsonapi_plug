defmodule JSONAPI.Plug.Params do
  @moduledoc """
  Transforms conn body params to denormalized form
  """

  alias JSONAPI.Normalizer
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{private: %{jsonapi: %JSONAPI{document: document, view: view}}} = conn, _options) do
    body_params = Normalizer.denormalize(document, view, conn)

    %Conn{
      conn
      | body_params: body_params,
        params:
          conn.params
          |> Map.drop(["data", "included"])
          |> Map.put("data", body_params)
    }
  end
end
