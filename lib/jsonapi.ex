defmodule JSONAPI do
  @moduledoc """
  Struct containing JSON API information for a request
  """

  alias JSONAPI.{Document, View}

  @type t :: %__MODULE__{
          document: Document.t() | nil,
          fields: map(),
          filter: keyword(),
          include: keyword(),
          opts: keyword(),
          sort: keyword(),
          view: View.t(),
          page: map()
        }
  defstruct document: nil,
            fields: %{},
            filter: [],
            include: [],
            opts: [],
            sort: [],
            view: nil,
            page: %{}

  @doc """
  This returns the MIME type for JSONAPIs
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"
end
