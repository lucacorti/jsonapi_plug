defmodule JSONAPIPlug.Document.ResourceIdentifierObject do
  @moduledoc """
  JSON:API Resource Identifier object

  https://jsonapi.org/format/#document-resource-object-linkage
  """

  alias JSONAPIPlug.{Document, Document.ResourceObject, Exceptions.InvalidDocument}

  @type t :: %__MODULE__{
          id: ResourceObject.id(),
          lid: ResourceObject.id(),
          type: ResourceObject.type(),
          meta: Document.meta() | nil
        }
  defstruct [:id, :lid, :meta, :type]

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{
      id: deserialize_id(data),
      lid: deserialize_lid(data),
      meta: deserialize_meta(data),
      type: deserialize_type(data)
    }
  end

  defp deserialize_id(%{"id" => id}) when is_binary(id) and byte_size(id) > 0, do: id
  defp deserialize_id(_data), do: nil

  defp deserialize_lid(%{"lid" => lid}) when is_binary(lid) and byte_size(lid) > 0, do: lid
  defp deserialize_lid(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta

  defp deserialize_meta(%{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource Identifier object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-identifier-objects"
  end

  defp deserialize_meta(_payload), do: nil

  defp deserialize_type(%{"type" => type}) when is_binary(type) and byte_size(type) > 0, do: type

  defp deserialize_type(type) do
    raise InvalidDocument,
      message: "Resource Identifier object type (#{type}) is invalid",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end
end
