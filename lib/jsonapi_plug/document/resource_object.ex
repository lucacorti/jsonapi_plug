defmodule JSONAPIPlug.Document.ResourceObject do
  @moduledoc """
  JSON:API Resource Object

  https://jsonapi.org/format/#resource_object-resource-objects
  """

  alias JSONAPIPlug.Document
  alias JSONAPIPlug.Document.{ErrorObject, LinkObject, RelationshipObject}
  alias JSONAPIPlug.Exceptions.InvalidDocument

  @type id :: String.t()
  @type type :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          lid: id(),
          type: type(),
          attributes: %{String.t() => Document.value()} | nil,
          links: Document.links() | nil,
          meta: Document.meta() | nil,
          relationships: %{String.t() => [RelationshipObject.t()]} | nil
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
    %__MODULE__{}
    |> deserialize_id(data)
    |> deserialize_lid(data)
    |> deserialize_type(data)
    |> deserialize_attributes(data)
    |> deserialize_links(data)
    |> deserialize_relationships(data)
    |> deserialize_meta(data)
  end

  defp deserialize_id(resource_object, %{"id" => id})
       when is_binary(id) and byte_size(id) > 0,
       do: %__MODULE__{resource_object | id: id}

  defp deserialize_id(resource_object, _data), do: resource_object

  defp deserialize_lid(resource_object, %{"lid" => lid})
       when is_binary(lid) and byte_size(lid) > 0,
       do: %__MODULE__{resource_object | lid: lid}

  defp deserialize_lid(resource_object, _data), do: resource_object

  defp deserialize_type(resource_object, %{"type" => type})
       when is_binary(type) and byte_size(type) > 0,
       do: %__MODULE__{resource_object | type: type}

  defp deserialize_type(_resource_object, %{"type" => type}) do
    raise InvalidDocument,
      message: "Resource object type (#{type}) is invalid",
      errors: [
        %ErrorObject{
          title: "Resource object type (#{type}) is invalid",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_attributes(_resource_object, %{"attributes" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'id'",
      errors: [
        %ErrorObject{
          title: "Resource object cannot have an attribute named 'id'",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_attributes(_resource_object, %{"attributes" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'type'",
      errors: [
        %ErrorObject{
          title: "Resource object cannot have an attribute named 'type'",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_attributes(resource_object, %{"attributes" => attributes})
       when is_map(attributes),
       do: %__MODULE__{resource_object | attributes: attributes}

  defp deserialize_attributes(resource_object, _data), do: resource_object

  defp deserialize_links(resource_object, %{"links" => links}),
    do: %__MODULE__{
      resource_object
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.deserialize(link)}
          end)
    }

  defp deserialize_links(resource_object, _data), do: resource_object

  defp deserialize_relationships(_resource_object, %{"relationships" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'id'",
      errors: [
        %ErrorObject{
          title: "Resource object cannot have a relationship named 'id'",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_relationships(_resource_object, %{"relationships" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'type'",
      errors: [
        %ErrorObject{
          title: "Resource object cannot have a relationship named 'type'",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_relationships(
         resource_object,
         %{"relationships" => relationships}
       )
       when is_map(relationships) do
    %__MODULE__{
      resource_object
      | relationships:
          Enum.into(relationships, %{}, fn
            {name, data} when is_list(data) ->
              {name, Enum.map(data, &RelationshipObject.deserialize/1)}

            {name, data} ->
              {name, RelationshipObject.deserialize(data)}
          end)
    }
  end

  defp deserialize_relationships(_resource_object, %{
         "relationships" => _relationships
       }) do
    raise InvalidDocument,
      message: "Resource object 'relationships' attribute must be an object",
      errors: [
        %ErrorObject{
          title: "Resource object 'relationships' attribute must be an object",
          detail: "https://jsonapi.org/format/#document-resource-object-relationships"
        }
      ]
  end

  defp deserialize_relationships(relationships, _data), do: relationships

  defp deserialize_meta(resource_object, %{"meta" => meta}) when is_map(meta),
    do: %__MODULE__{resource_object | meta: meta}

  defp deserialize_meta(_resource_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource object 'meta' must be an object",
      errors: [
        %ErrorObject{
          title: "Resource object 'meta' must be an object",
          detail: "https://jsonapi.org/format/#document-resource-objects"
        }
      ]
  end

  defp deserialize_meta(resource_object, _data), do: resource_object

  @spec serialize(t()) :: t()
  def serialize(resource_object), do: resource_object
end
