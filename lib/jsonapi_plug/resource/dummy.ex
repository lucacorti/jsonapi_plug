defmodule JSONAPIPlug.Resource.Dummy do
  # IGNORE: Dummy resource implementation to avoid warnings during development when compiling the library
  @moduledoc false
  @derive {JSONAPIPlug.Resource, type: "dummy", attributes: [:field]}
  defstruct [:field]
end
