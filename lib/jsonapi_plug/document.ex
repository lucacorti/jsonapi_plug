defmodule JSONAPIPlug.Document do
  @moduledoc """
  JSON:API Document

  This module defines the structure of a `JSON:API` document and functions that handle
  serialization and deserialization. This also handles validation of `JSON:API` documents.

  https://jsonapi.org/format/#document-structure
  """

  alias JSONAPIPlug.{
    Document.ErrorObject,
    Document.JSONAPIObject,
    Document.LinkObject,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument,
    View
  }

  @type value :: String.t() | integer() | float() | [value()] | %{String.t() => value()} | nil

  @type payload :: %{String.t() => value()}

  @typedoc """
  JSON:API Primary Data

  https://jsonapi.org/format/#document-top-level
  """
  @type data :: ResourceObject.t() | [ResourceObject.t()]

  @typedoc """
  JSON:API Errors

  https://jsonapi.org/format/#errors
  """
  @type errors :: [ErrorObject.t()]

  @typedoc """
  JSON:API Included Resources

  https://jsonapi.org/format/#document-compound-documents
  """
  @type included :: [ResourceObject.t()]

  @typedoc """
  JSON:API Object

  https://jsonapi.org/format/#document-jsonapi-object
  """
  @type jsonapi :: JSONAPIObject.t()

  @typedoc """
  JSON:API Meta Information

  https://jsonapi.org/format/#document-meta
  """
  @type meta :: payload()

  @typedoc """
  JSON:API Links

  https://jsonapi.org/format/#document-links
  """
  @type links :: %{atom() => LinkObject.t()}

  @typedoc """
  JSONA:API Document

  https://jsonapi.org/format/#document-structure
  """
  @type t :: %__MODULE__{
          data: data() | View.data() | nil,
          errors: errors() | nil,
          included: included() | nil,
          jsonapi: jsonapi() | nil,
          links: links() | nil,
          meta: meta() | nil
        }
  defstruct [:data, :errors, :included, :jsonapi, :links, :meta]

  @spec deserialize(payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{}
    |> deserialize_data(data)
    |> deserialize_errors(data)
    |> deserialize_included(data)
    |> deserialize_jsonapi(data)
    |> deserialize_links(data)
    |> deserialize_meta(data)
  end

  defp deserialize_data(_document, %{"data" => _data, "errors" => _errors}) do
    raise InvalidDocument,
      message: "Document cannot contain both 'data' and 'errors' members",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_data(document, %{"data" => resources}) when is_list(resources),
    do: %__MODULE__{
      document
      | data: Enum.map(resources, &ResourceObject.deserialize/1)
    }

  defp deserialize_data(document, %{"data" => resource_object}) when is_map(resource_object),
    do: %__MODULE__{document | data: ResourceObject.deserialize(resource_object)}

  defp deserialize_data(document, _data), do: document

  defp deserialize_errors(document, %{"errors" => errors}) when is_list(errors),
    do: %__MODULE__{document | errors: Enum.map(errors, &ErrorObject.deserialize/1)}

  defp deserialize_errors(document, _data), do: document

  defp deserialize_included(document, %{"data" => _data, "included" => included})
       when is_list(included) do
    %__MODULE__{
      document
      | included: Enum.map(included, &ResourceObject.deserialize/1)
    }
  end

  defp deserialize_included(_document, %{"included" => included})
       when is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' cannot be present if 'data' isn't also present",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_included(_document, %{"included" => included})
       when is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' must be a list",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp deserialize_included(document, _data), do: document

  defp deserialize_jsonapi(document, %{"jsonapi" => jsonapi}) when is_map(jsonapi),
    do: %__MODULE__{document | jsonapi: JSONAPIObject.deserialize(jsonapi)}

  defp deserialize_jsonapi(document, _data), do: document

  defp deserialize_links(document, %{"links" => links}) when is_map(links),
    do: %__MODULE__{
      document
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.deserialize(link)}
          end)
    }

  defp deserialize_links(document, _data), do: document

  defp deserialize_meta(document, %{"meta" => meta}) when is_map(meta),
    do: %__MODULE__{document | meta: meta}

  defp deserialize_meta(_document, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Document 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-meta"
  end

  defp deserialize_meta(document, _data), do: document

  @spec serialize(t()) :: t() | no_return()
  def serialize(document) do
    document
    |> serialize_data()
    |> serialize_errors()
    |> serialize_meta()
    |> serialize_included()
  end

  defp serialize_data(%__MODULE__{data: %ResourceObject{} = resource} = document),
    do: %__MODULE__{document | data: ResourceObject.serialize(resource)}

  defp serialize_data(%__MODULE__{data: resources} = document) when is_list(resources),
    do: %__MODULE__{document | data: Enum.map(resources, &ResourceObject.serialize/1)}

  defp serialize_data(%__MODULE__{data: nil} = document), do: document

  defp serialize_errors(%__MODULE__{data: data, errors: errors})
       when not is_nil(data) and not is_nil(errors) do
    raise InvalidDocument,
      message: "Document cannot contain both 'data' and 'errors' members",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_errors(%__MODULE__{errors: errors})
       when not is_nil(errors) and not is_list(errors) do
    raise InvalidDocument,
      message: "Document 'errors' must be a list",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_errors(%__MODULE__{errors: errors} = document) when is_list(errors),
    do: %__MODULE__{document | errors: Enum.map(errors, &ErrorObject.serialize/1)}

  defp serialize_errors(document), do: document

  defp serialize_included(%__MODULE__{included: included})
       when not is_nil(included) and not is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' must be a list resource objects",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_included(%__MODULE__{included: included} = document) when is_list(included),
    do: %__MODULE__{document | included: Enum.map(included, &ResourceObject.serialize/1)}

  defp serialize_included(document), do: document

  defp serialize_meta(%__MODULE__{meta: meta}) when not is_nil(meta) and not is_map(meta) do
    raise InvalidDocument,
      message: "Document 'meta' must be a map",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp serialize_meta(document), do: document

  defimpl Jason.Encoder,
    for: [
      __MODULE__,
      ErrorObject,
      LinkObject,
      ResourceIdentifierObject,
      ResourceObject,
      RelationshipObject
    ] do
    def encode(document, options) do
      document
      |> Map.from_struct()
      |> Enum.reduce(%{}, fn
        {_key, nil}, data -> data
        {_key, %{} = map}, data when map_size(map) == 0 -> data
        {key, value}, data -> Map.put(data, key, value)
      end)
      |> Jason.Encode.map(options)
    end
  end
end
