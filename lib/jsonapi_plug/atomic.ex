defmodule JSONAPIPlug.Atomic do
  @moduledoc "Atomic Operations Extension"

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ErrorObject
  alias JSONAPIPlug.Atomic.{OperationObject, ResultObject}

  @type t :: %__MODULE__{
          errors: [ErrorObject.t()],
          operations: [OperationObject.t()],
          results: [ResultObject.t()]
        }
  defstruct errors: [], operations: [], results: []

  @spec serialize(t()) :: Document.payload()
  def serialize(%__MODULE__{} = atomic) do
    %{} |> serialize_results(atomic) |> serialize_errors(atomic)
  end

  defp serialize_errors(data, %__MODULE__{errors: []}), do: data

  defp serialize_errors(data, %__MODULE__{} = atomic),
    do: Map.put(data, "errors", atomic.errors)

  defp serialize_results(data, %__MODULE__{results: []}), do: data

  defp serialize_results(data, %__MODULE__{} = atomic),
    do: Map.put(data, "atomic:results", atomic.results)

  @spec deserialize(Document.payload()) :: t()
  def deserialize(%{"atomic:operations" => operations}) when is_list(operations),
    do: %__MODULE__{operations: Enum.map(operations, &OperationObject.deserialize/1)}

  def deserialize(_data), do: %__MODULE__{}
end
