defmodule JSONAPIPlug.Document.JSONAPIObject do
  @moduledoc """
  JSON:API Document JSON:API Object
  """

  alias JSONAPIPlug.{Document, Exceptions.InvalidDocument}

  @type version :: :"1.0"

  @type t :: %__MODULE__{meta: Document.meta() | nil, version: version()}
  defstruct meta: nil, version: nil

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) do
    %__MODULE__{}
    |> parse_meta(data)
    |> parse_version(data)
  end

  defp parse_meta(%__MODULE__{} = jsonapi_object, %{"meta" => meta}) when is_map(meta),
    do: %{jsonapi_object | meta: meta}

  defp parse_meta(_jsonapi_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "JSON:API object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp parse_meta(jsonapi_object, _data), do: jsonapi_object

  defp parse_version(%__MODULE__{} = jsonapi_object, %{"version" => "1.0"}),
    do: %{jsonapi_object | version: :"1.0"}

  defp parse_version(%__MODULE__{} = jsonapi_object, %{"version" => "1.1"}),
    do: %{jsonapi_object | version: :"1.1"}

  defp parse_version(_jsonapi_object, %{"version" => version}) do
    raise InvalidDocument,
      message: "JSON:API Object has invalid version (#{version})",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp parse_version(jsonapi_object, _data), do: jsonapi_object
end
