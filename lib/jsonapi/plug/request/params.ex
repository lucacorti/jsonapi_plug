defmodule JSONAPI.Plug.Request.Params do
  @moduledoc """
  Transforms conn body params to denormalized form
  """

  alias JSONAPI.Normalizer
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{private: %{jsonapi: %JSONAPI{document: document, view: view}}} = conn, _options),
    do: %Conn{conn | body_params: Normalizer.denormalize(document, view, conn)}
end
