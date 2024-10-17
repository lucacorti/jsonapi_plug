defmodule JSONAPIPlug.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#resource_object-resource-objects
  """

  alias JSONAPIPlug.{
    Document,
    Document.LinkObject,
    Document.RelationshipObject,
    Exceptions.InvalidDocument
  }

  @type id :: String.t()
  @type type :: String.t()

  @type t :: %__MODULE__{
          id: id() | nil,
          lid: id() | nil,
          type: type(),
          attributes: %{String.t() => Document.value()},
          links: Document.links() | nil,
          meta: Document.meta() | nil,
          relationships: %{String.t() => [RelationshipObject.t()]}
        }
  defstruct id: nil,
            lid: nil,
            type: nil,
            attributes: %{},
            relationships: %{},
            links: nil,
            meta: nil

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{
      id: deserialize_id(data),
      lid: deserialize_lid(data),
      type: deserialize_type(data),
      attributes: deserialize_attributes(data),
      links: deserialize_links(data),
      relationships: deserialize_relationships(data),
      meta: deserialize_meta(data)
    }
  end

  defp deserialize_id(%{"id" => id}) when is_binary(id) and byte_size(id) > 0, do: id
  defp deserialize_id(_data), do: nil

  defp deserialize_lid(%{"lid" => lid}) when is_binary(lid) and byte_size(lid) > 0, do: lid
  defp deserialize_lid(_data), do: nil

  defp deserialize_type(%{"type" => type}) when is_binary(type) and byte_size(type) > 0, do: type

  defp deserialize_type(%{"type" => type}) do
    raise InvalidDocument,
      message: "Resource object type '#{type}' is invalid",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_attributes(%{"attributes" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'id'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_attributes(%{"attributes" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'type'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_attributes(%{"attributes" => attributes})
       when is_map(attributes),
       do: attributes

  defp deserialize_attributes(_data), do: %{}

  defp deserialize_links(%{"links" => links}),
    do:
      Enum.into(links, %{}, fn {name, link} ->
        {name, LinkObject.deserialize(link)}
      end)

  defp deserialize_links(_data), do: nil

  defp deserialize_relationships(%{"relationships" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'id'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_relationships(%{"relationships" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'type'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_relationships(%{"relationships" => relationships})
       when is_map(relationships) do
    Enum.into(relationships, %{}, fn
      {name, data} when is_list(data) ->
        {name, Enum.map(data, &RelationshipObject.deserialize/1)}

      {name, data} ->
        {name, RelationshipObject.deserialize(data)}
    end)
  end

  defp deserialize_relationships(%{
         "relationships" => _relationships
       }) do
    raise InvalidDocument,
      message: "Resource object 'relationships' attribute must be an object",
      reference: "https://jsonapi.org/format/#document-resource-object-relationships"
  end

  defp deserialize_relationships(_data), do: %{}

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta

  defp deserialize_meta(%{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp deserialize_meta(_data), do: nil

  @spec serialize(t()) :: t()
  def serialize(resource_object), do: resource_object
end
