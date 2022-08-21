defmodule JSONAPI.Plug.Params do
  @moduledoc """
  Transforms conn body params to denormalized form
  """

  alias JSONAPI.API
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn, _options) do
    normalizer = API.get_config(jsonapi.api, [:normalizer])
    body_params = normalizer.denormalize(jsonapi.document, jsonapi.view, conn)

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
