defmodule JSONAPI.Resource.NotLoaded do
  @moduledoc """
  Placeholder for unloaded relationships
  """

  alias JSONAPI.Resource

  @type t :: %__MODULE__{type: Resource.type()}
  defstruct [:type]
end
