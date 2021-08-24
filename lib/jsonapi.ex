defmodule JSONAPI do
  @moduledoc """
  Struct containing JSON API information for a request
  """

  alias JSONAPI.View

  @type t :: %__MODULE__{
          data: nil | map(),
          fields: map(),
          filter: keyword(),
          include: keyword(),
          opts: keyword(),
          sort: nil | keyword(),
          view: View.t(),
          page: map()
        }
  defstruct data: nil,
            fields: %{},
            filter: [],
            include: [],
            opts: [],
            sort: nil,
            view: nil,
            page: %{}

  @doc """
  This returns the MIME type for JSONAPIs
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"
end
