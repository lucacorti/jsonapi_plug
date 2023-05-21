defmodule JSONAPIPlug.Document do
  @moduledoc """
  JSON:API Document

  This module defines the structure of a `JSON:API` document and functions to handle
  parsing and validation of `JSON:API` documents.

  https://jsonapi.org/format/#document-structure
  """

  alias JSONAPIPlug.{
    Document.ErrorObject,
    Document.JSONAPIObject,
    Document.LinkObject,
    Document.ResourceObject,
    Exceptions.InvalidDocument
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
  JSON:API Document

  https://jsonapi.org/format/#document-structure
  """
  @type t :: %__MODULE__{
          data: data() | nil,
          errors: errors() | nil,
          included: included() | nil,
          jsonapi: jsonapi() | nil,
          links: links() | nil,
          meta: meta() | nil
        }
  defstruct [:data, :errors, :included, :jsonapi, :links, :meta]

  @doc """
  Parses JSON:API Document

  Takes a map representing a JSON:API Document as input and parses it.
  """
  @spec parse(payload()) :: t() | no_return()
  def parse(data) do
    %__MODULE__{}
    |> parse_data(data)
    |> parse_errors(data)
    |> parse_included(data)
    |> parse_jsonapi(data)
    |> parse_links(data)
    |> parse_meta(data)
  end

  defp parse_data(_document, %{"data" => _data, "errors" => _errors}) do
    raise InvalidDocument,
      message: "Document cannot contain both 'data' and 'errors' members",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp parse_data(%__MODULE__{} = document, %{"data" => resources}) when is_list(resources),
    do: %{
      document
      | data: Enum.map(resources, &ResourceObject.parse/1)
    }

  defp parse_data(%__MODULE__{} = document, %{"data" => resource_object})
       when is_map(resource_object),
       do: %{document | data: ResourceObject.parse(resource_object)}

  defp parse_data(document, _data), do: document

  defp parse_errors(%__MODULE__{} = document, %{"errors" => errors}) when is_list(errors),
    do: %{document | errors: Enum.map(errors, &ErrorObject.parse/1)}

  defp parse_errors(document, _data), do: document

  defp parse_included(%__MODULE__{} = document, %{"data" => _data, "included" => included})
       when is_list(included) do
    %{
      document
      | included: Enum.map(included, &ResourceObject.parse/1)
    }
  end

  defp parse_included(_document, %{"included" => included})
       when is_list(included) do
    raise InvalidDocument,
      message: "Document 'included' cannot be present if 'data' isn't also present",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp parse_included(_document, %{"included" => included})
       when not is_nil(included) do
    raise InvalidDocument,
      message: "Document 'included' must be a list",
      reference: "https://jsonapi.org/format/#document-top-level"
  end

  defp parse_included(document, _data), do: document

  defp parse_jsonapi(%__MODULE__{} = document, %{"jsonapi" => jsonapi}) when is_map(jsonapi),
    do: %{document | jsonapi: JSONAPIObject.parse(jsonapi)}

  defp parse_jsonapi(document, _data), do: document

  defp parse_links(%__MODULE__{} = document, %{"links" => links}) when is_map(links),
    do: %{
      document
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.parse(link)}
          end)
    }

  defp parse_links(document, _data), do: document

  defp parse_meta(%__MODULE__{} = document, %{"meta" => meta}) when is_map(meta),
    do: %{document | meta: meta}

  defp parse_meta(_document, %{"meta" => meta}) when not is_nil(meta) do
    raise InvalidDocument,
      message: "Document 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-meta"
  end

  defp parse_meta(document, _data), do: document
end

defimpl Jason.Encoder,
  for: [
    JSONAPIPlug.Document,
    JSONAPIPlug.Document.ErrorObject,
    JSONAPIPlug.Document.JSONAPIObject,
    JSONAPIPlug.Document.LinkObject,
    JSONAPIPlug.Document.RelationshipObject,
    JSONAPIPlug.Document.ResourceIdentifierObject,
    JSONAPIPlug.Document.ResourceObject
  ] do
  def encode(object, options) do
    object
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn
      {:data = key, nil}, data -> Map.put(data, key, nil)
      {_key, nil}, data -> data
      {_key, %{} = map}, data when map_size(map) == 0 -> data
      {key, value}, data -> Map.put(data, key, value)
    end)
    |> Jason.Encode.map(options)
  end
end
