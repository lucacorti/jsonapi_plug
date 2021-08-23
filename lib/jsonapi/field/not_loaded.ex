defmodule JSONAPI.Field.NotLoaded do
  @moduledoc """
  Placeholder for missing JSON:API fields
  """

  alias JSONAPI.Resource

  @type t :: %__MODULE__{
          id: Resource.id(),
          type: Resource.type()
        }
  defstruct [:id, :type]
end
