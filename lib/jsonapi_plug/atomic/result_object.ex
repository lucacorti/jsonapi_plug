defmodule JSONAPIPlug.Atomic.ResultObject do
  @moduledoc "Atomic Operations Result Object"

  alias JSONAPIPlug.Document

  @type t :: %__MODULE__{
          data: Document.data(),
          meta: Document.meta()
        }
  defstruct [:data, :meta]
end
