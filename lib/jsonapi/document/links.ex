defmodule JSONAPI.Document.Links do
  @moduledoc """
  JSONAPI Document Links
  """

  @type t :: %__MODULE__{
          related: String.t(),
          self: String.t()
        }
  defstruct related: nil, self: nil
end
