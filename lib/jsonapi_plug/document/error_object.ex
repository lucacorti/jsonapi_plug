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

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) do
    struct(
      %__MODULE__{},
      %__MODULE__{}
      |> Map.from_struct()
      |> Enum.reduce([], fn {key, _value}, attrs ->
        case Map.fetch(data, Atom.to_string(key)) do
          {:ok, value} -> Map.put(attrs, key, value)
          :error -> attrs
        end
      end)
    )
  end
end
