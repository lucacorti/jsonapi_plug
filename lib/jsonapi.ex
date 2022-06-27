defmodule JSONAPI do
  @moduledoc """
  JSON:API Context

  Stores configuration and parsed request information
  """

  alias JSONAPI.{API, Document, View}

  @type t :: %__MODULE__{
          api: API.t(),
          fields: map(),
          filter: map(),
          include: keyword(),
          options: keyword(),
          page: map(),
          request: Document.t() | nil,
          sort: keyword(),
          view: View.t()
        }
  defstruct api: nil,
            fields: %{},
            filter: %{},
            include: [],
            options: [],
            page: %{},
            request: nil,
            sort: [],
            view: nil

  @doc """
  JSON:API MIME type
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"
end
