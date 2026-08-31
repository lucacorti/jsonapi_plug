defmodule JSONAPIPlug.Document.JSONAPIObject do
  @moduledoc """
  JSON:API Document JSON:API Object
  """

  alias JSONAPIPlug.{Document, Exceptions.InvalidDocument}

  @type version :: :"1.0" | :"1.1"

  @type t :: %__MODULE__{
          ext: [String.t()] | nil,
          meta: Document.meta() | nil,
          profile: [String.t()] | nil,
          version: version() | nil
        }
  defstruct ext: nil, meta: nil, profile: nil, version: nil

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{
      ext: deserialize_ext(data),
      meta: deserialize_meta(data),
      profile: deserialize_profile(data),
      version: deserialize_version(data)
    }
  end

  defp deserialize_ext(%{"ext" => ext}) when is_list(ext), do: ext

  defp deserialize_ext(%{"ext" => _ext}) do
    raise InvalidDocument,
      message: "JSON:API object 'ext' must be an array",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp deserialize_ext(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta

  defp deserialize_meta(%{"meta" => _meta}) do
    raise InvalidDocument,
      message: "JSON:API object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp deserialize_meta(_data), do: nil

  defp deserialize_profile(%{"profile" => profile}) when is_list(profile), do: profile

  defp deserialize_profile(%{"profile" => _profile}) do
    raise InvalidDocument,
      message: "JSON:API object 'profile' must be an array",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp deserialize_profile(_data), do: nil

  defp deserialize_version(%{"version" => "1.0"}), do: :"1.0"
  defp deserialize_version(%{"version" => "1.1"}), do: :"1.1"

  defp deserialize_version(%{"version" => version}) do
    raise InvalidDocument,
      message: "JSON:API Object has invalid version (#{version})",
      reference: "https://jsonapi.org/format/#document-jsonapi-object"
  end

  defp deserialize_version(_data), do: nil
end
