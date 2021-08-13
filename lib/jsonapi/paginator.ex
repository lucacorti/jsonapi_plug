defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  alias JSONAPI.{Document, Resource, View}
  alias Plug.Conn

  @type t :: module()

  @type options :: Keyword.t()

  @type params :: %{String.t() => String.t()}

  @callback paginate(
              View.t(),
              [Resource.t()],
              Conn.t() | nil,
              params(),
              View.options()
            ) :: Document.links()
end
