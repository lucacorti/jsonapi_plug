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
          links: %{String.t() => String.t()} | nil,
          meta: %{String.t() => String.t()} | nil,
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
    error = %__MODULE__{}

    attrs =
      error
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reduce([], fn key, attrs ->
        case Map.fetch(data, Atom.to_string(key)) do
          {:ok, value} -> Map.put(attrs, key, value)
          :error -> attrs
        end
      end)

    struct(%__MODULE__{}, attrs)
  end

  @spec serialize(t()) :: t()
  def serialize(error_object), do: error_object
end
