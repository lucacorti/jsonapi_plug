defmodule JSONAPIPlug.Document.JSONAPIObject do
  @moduledoc """
  JSON:API Document JSON:API Object
  """

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ErrorObject
  alias JSONAPIPlug.Exceptions.InvalidDocument

  @type version :: :"1.0"

  @type t :: %__MODULE__{meta: Document.meta() | nil, version: version()}
  defstruct meta: nil, version: nil

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{}
    |> deserialize_meta(data)
    |> deserialize_version(data)
  end

  defp deserialize_meta(jsonapi_object, %{"meta" => meta}) when is_map(meta),
    do: %__MODULE__{jsonapi_object | meta: meta}

  defp deserialize_meta(_jsonapi_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "JSON:API Object 'meta' must be an object",
      errors: [
        %ErrorObject{
          title: "JSON:API object 'meta' must be an object",
          detail: "https://jsonapi.org/format/#document-jsonapi-object",
          source: %{pointer: "/jsonapi/meta"}
        }
      ]
  end

  defp deserialize_meta(jsonapi_object, _data), do: jsonapi_object

  defp deserialize_version(jsonapi_object, %{"version" => "1.0"}),
    do: %__MODULE__{jsonapi_object | version: :"1.0"}

  defp deserialize_version(jsonapi_object, %{"version" => "1.1"}),
    do: %__MODULE__{jsonapi_object | version: :"1.1"}

  defp deserialize_version(_jsonapi_object, %{"version" => version}) do
    raise InvalidDocument,
      message: "JSON:API Object has invalid version (#{version})",
      errors: [
        %ErrorObject{
          title: "JSON:API Object has invalid version (#{version})",
          detail: "https://jsonapi.org/format/#document-jsonapi-object",
          source: %{pointer: "/jsonapi/version"}
        }
      ]
  end

  defp deserialize_version(jsonapi_object, _data), do: jsonapi_object
end
