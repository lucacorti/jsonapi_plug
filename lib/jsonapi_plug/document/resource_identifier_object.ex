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
    %__MODULE__{}
    |> deserialize_id(data)
    |> deserialize_lid(data)
    |> deserialize_meta(data)
    |> deserialize_type(data)
  end

  defp deserialize_id(resource_identifier_object, %{"id" => id})
       when is_binary(id) and byte_size(id) > 0,
       do: %__MODULE__{resource_identifier_object | id: id}

  defp deserialize_id(resource_identifier_object, _data),
    do: resource_identifier_object

  defp deserialize_lid(resource_object, %{"lid" => lid})
       when is_binary(lid) and byte_size(lid) > 0,
       do: %__MODULE__{resource_object | lid: lid}

  defp deserialize_lid(resource_object, _data), do: resource_object

  defp deserialize_meta(resource_identifier_object, %{"meta" => meta})
       when is_map(meta),
       do: %__MODULE__{resource_identifier_object | meta: meta}

  defp deserialize_meta(_resource_identifier_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource Identifier object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-identifier-objects"
  end

  defp deserialize_meta(resource_identifier_object, _payload),
    do: resource_identifier_object

  defp deserialize_type(resource_identifier_object, %{"type" => type})
       when is_binary(type) and byte_size(type) > 0,
       do: %__MODULE__{resource_identifier_object | type: type}

  defp deserialize_type(_resource_identifier_object, type) do
    raise InvalidDocument,
      message: "Resource Identifier object type (#{type}) is invalid",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end
end
