defmodule JSONAPIPlug.Document.ErrorObject do
  @moduledoc """
  JSON:API Error Object

  https://jsonapi.org/format/#error-objects
  """

  alias JSONAPIPlug.Document

  @type t :: %__MODULE__{
          code: String.t() | nil,
          detail: String.t() | nil,
          id: String.t() | nil,
          links: Document.links() | nil,
          meta: Document.meta() | nil,
          source: %{pointer: String.t()} | nil,
          status: String.t() | nil,
          title: String.t() | nil
        }
  defstruct code: nil,
            detail: nil,
            id: nil,
            links: nil,
            meta: nil,
            source: nil,
            status: nil,
            title: nil

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{
      code: data["code"],
      detail: data["detail"],
      id: data["id"],
      links: data["links"],
      meta: data["meta"],
      source: data["source"],
      status: data["status"],
      title: data["title"]
    }
  end

  @spec serialize(t()) :: t()
  def serialize(error_object), do: error_object
end
