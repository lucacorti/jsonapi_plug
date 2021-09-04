defmodule JSONAPI do
  @moduledoc """
  Struct containing JSON API information for a request
  """

  alias JSONAPI.{API, Document, View}

  @type t :: %__MODULE__{
          api: API.t(),
          fields: map(),
          filter: keyword(),
          include: keyword(),
          opts: keyword(),
          request: Document.t() | nil,
          sort: keyword(),
          view: View.t(),
          page: map()
        }
  defstruct api: nil,
            fields: %{},
            filter: [],
            include: [],
            page: %{},
            opts: [],
            request: nil,
            sort: [],
            view: nil

  @doc """
  This returns the MIME type for JSONAPIs
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"
end
