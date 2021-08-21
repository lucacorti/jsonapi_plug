defmodule JSONAPI.Resource.NotLoaded do
  @moduledoc """
  Placeholder for unloaded relationships
  """

  alias JSONAPI.Resource

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type()
        }
  @enforce_keys [:id, :type]
  defstruct [:id, :type]
end
