defmodule JSONAPI.Document.LinksObject do
  @moduledoc """
  JSON:API Links Object

  https://jsonapi.org/format/#document-links
  """

  alias JSONAPI.Document

  @type link :: t() | String.t()

  @type t :: %__MODULE__{self: link() | nil, related: link() | nil}
  defstruct [:self, :related]

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
end
