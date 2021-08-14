defmodule JSONAPI.Document.JSONAPIObject do
  @moduledoc """
  JSONAPI Document JSONAPI Object
  """

  @type t :: %__MODULE__{version: String.t()}
  defstruct version: "1.0"
end
