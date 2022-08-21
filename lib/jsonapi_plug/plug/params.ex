defmodule JSONAPIPlug.Plug.Params do
  @moduledoc """
  Transforms conn body params to denormalized form
  """

  alias JSONAPIPlug.API
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, _options) do
    normalizer = API.get_config(jsonapi_plug.api, [:normalizer])
    body_params = normalizer.denormalize(jsonapi_plug.document, jsonapi_plug.view, conn)

    %Conn{
      conn
      | body_params: body_params,
        params:
          conn.params
          |> Map.drop(["errors", "included", "jsonapi", "links", "meta"])
          |> Map.put("data", body_params)
    }
  end
end
