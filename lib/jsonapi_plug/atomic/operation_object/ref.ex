defmodule JSONAPIPlug.Atomic.OperationObject.Ref do
  @moduledoc "Atomic Operations Ref"

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ResourceObject

  @type relationship :: String.t()

  @type t :: %__MODULE__{
          id: ResourceObject.id(),
          lid: ResourceObject.id(),
          relationship: relationship(),
          type: ResourceObject.type()
        }
  defstruct [:id, :lid, :relationship, :type]

  @spec deserialize(Document.payload()) :: t()
  def deserialize(data) do
    %__MODULE__{
      id: data["id"],
      lid: data["lid"],
      relationship: data["relationship"],
      type: data["type"]
    }
  end
end
