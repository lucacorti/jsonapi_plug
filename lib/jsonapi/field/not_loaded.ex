defmodule JSONAPI.Field.NotLoaded do
  @moduledoc """
  Placeholder for missing JSON:API fields
  """

  alias JSONAPI.Resource

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type(),
          field: Resource.field()
        }
  @enforce_keys [:field]
  defstruct [:id, :type, :field]
end
