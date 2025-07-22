defmodule JSONAPIPlug.Document.JSONAPIObject do
  @moduledoc """
  JSON:API Document JSON:API Object
  """

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.ErrorObject
  alias JSONAPIPlug.Exceptions.InvalidDocument

  @type version :: :"1.0" | :"1.1"

  @type t :: %__MODULE__{meta: Document.meta() | nil, version: version() | nil}
  defstruct meta: nil, version: nil

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{meta: deserialize_meta(data), version: deserialize_version(data)}
  end

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta

  defp deserialize_meta(%{"meta" => _meta}) do
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

  defp deserialize_meta(_data), do: nil
  defp deserialize_version(%{"version" => "1.0"}), do: :"1.0"
  defp deserialize_version(%{"version" => "1.1"}), do: :"1.1"

  defp deserialize_version(%{"version" => version}) do
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

  defp deserialize_version(_data), do: nil
end
