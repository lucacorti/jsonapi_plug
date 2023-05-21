defmodule JSONAPIPlug.Document.ResourceIdentifierObject do
  @moduledoc """
  JSON:API Resource Identifier object

  https://jsonapi.org/format/#document-resource-object-linkage
  """

  alias JSONAPIPlug.{Document, Document.ResourceObject, Exceptions.InvalidDocument}

  @type t :: %__MODULE__{
          id: ResourceObject.id(),
          type: ResourceObject.type(),
          meta: Document.meta() | nil
        }
  defstruct [:id, :type, :meta]

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) do
    %__MODULE__{}
    |> parse_id(data)
    |> parse_type(data)
    |> parse_meta(data)
  end

  defp parse_type(%__MODULE__{} = resource_identifier_object, %{"type" => type})
       when is_binary(type) and byte_size(type) > 0,
       do: %{resource_identifier_object | type: type}

  defp parse_type(_resource_identifier_object, type) do
    raise InvalidDocument,
      message: "Resource Identifier object type (#{type}) is invalid",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_id(%__MODULE__{} = resource_identifier_object, %{"id" => id})
       when is_binary(id) and byte_size(id) > 0,
       do: %{resource_identifier_object | id: id}

  defp parse_id(resource_identifier_object, _data),
    do: resource_identifier_object

  defp parse_meta(%__MODULE__{} = resource_identifier_object, %{"meta" => meta})
       when is_map(meta),
       do: %{resource_identifier_object | meta: meta}

  defp parse_meta(_resource_identifier_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource Identifier object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-identifier-objects"
  end

  defp parse_meta(resource_identifier_object, _payload),
    do: resource_identifier_object
end
