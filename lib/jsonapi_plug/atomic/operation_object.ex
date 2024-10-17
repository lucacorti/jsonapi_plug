defmodule JSONAPIPlug.Atomic.OperationObject do
  @moduledoc "Atomic Operations Operation Object"

  alias JSONAPIPlug.Atomic.OperationObject.Ref
  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ResourceObject

  @type op :: :add | :remove | :update

  @type t :: %__MODULE__{
          op: op(),
          data: Document.data(),
          meta: Document.meta(),
          href: String.t(),
          ref: Ref.t()
        }
  defstruct [:op, :data, :href, :meta, :ref]

  @spec deserialize(Document.payload()) :: t()
  def deserialize(data) do
    %__MODULE__{}
    |> deserialize_op(data)
    |> deserialize_data(data)
    |> deserialize_href(data)
    |> deserialize_meta(data)
    |> deserialize_ref(data)
  end

  defp deserialize_op(operation, %{"op" => "add"}), do: %__MODULE__{operation | op: :add}
  defp deserialize_op(operation, %{"op" => "remove"}), do: %__MODULE__{operation | op: :remove}
  defp deserialize_op(operation, %{"op" => "update"}), do: %__MODULE__{operation | op: :update}
  defp deserialize_op(operation, _data), do: operation

  defp deserialize_data(operation, %{"data" => data}),
    do: %__MODULE__{operation | data: ResourceObject.deserialize(data)}

  defp deserialize_data(operation, _data), do: operation

  defp deserialize_meta(operation, %{"meta" => meta}),
    do: %__MODULE__{operation | meta: meta}

  defp deserialize_meta(operation, _data), do: operation

  defp deserialize_href(operation, %{"href" => href}),
    do: %__MODULE__{operation | href: href}

  defp deserialize_href(operation, _data), do: operation

  defp deserialize_ref(operation, %{"ref" => ref}),
    do: %__MODULE__{operation | ref: Ref.deserialize(ref)}

  defp deserialize_ref(operation, _data), do: operation
end
