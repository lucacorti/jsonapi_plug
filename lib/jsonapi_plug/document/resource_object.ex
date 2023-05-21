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

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) do
    %__MODULE__{}
    |> parse_id(data)
    |> parse_lid(data)
    |> parse_type(data)
    |> parse_attributes(data)
    |> parse_links(data)
    |> parse_relationships(data)
    |> parse_meta(data)
  end

  defp parse_id(%__MODULE__{} = resource_object, %{"id" => id})
       when is_binary(id) and byte_size(id) > 0,
       do: %{resource_object | id: id}

  defp parse_id(resource_object, _data), do: resource_object

  defp parse_lid(%__MODULE__{} = resource_object, %{"lid" => lid})
       when is_binary(lid) and byte_size(lid) > 0,
       do: %{resource_object | lid: lid}

  defp parse_lid(resource_object, _data), do: resource_object

  defp parse_type(%__MODULE__{} = resource_object, %{"type" => type})
       when is_binary(type) and byte_size(type) > 0,
       do: %{resource_object | type: type}

  defp parse_type(_resource_object, %{"type" => type}) do
    raise InvalidDocument,
      message: "Resource object type (#{type}) is invalid",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_attributes(_resource_object, %{"attributes" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'id'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_attributes(_resource_object, %{"attributes" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have an attribute named 'type'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_attributes(%__MODULE__{} = resource_object, %{"attributes" => attributes})
       when is_map(attributes),
       do: %{resource_object | attributes: attributes}

  defp parse_attributes(resource_object, _data), do: resource_object

  defp parse_links(%__MODULE__{} = resource_object, %{"links" => links}),
    do: %{
      resource_object
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.parse(link)}
          end)
    }

  defp parse_links(resource_object, _data), do: resource_object

  defp parse_relationships(_resource_object, %{"relationships" => %{"id" => _id}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'id'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_relationships(_resource_object, %{"relationships" => %{"type" => _type}}) do
    raise InvalidDocument,
      message: "Resource object cannot have a relationship named 'type'",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_relationships(
         %__MODULE__{} = resource_object,
         %{"relationships" => relationships}
       )
       when is_map(relationships) do
    %{
      resource_object
      | relationships:
          Enum.into(relationships, %{}, fn
            {name, data} when is_list(data) ->
              {name, Enum.map(data, &RelationshipObject.parse/1)}

            {name, data} ->
              {name, RelationshipObject.parse(data)}
          end)
    }
  end

  defp parse_relationships(_resource_object, %{
         "relationships" => _relationships
       }) do
    raise InvalidDocument,
      message: "Resource object 'relationships' attribute must be an object",
      reference: "https://jsonapi.org/format/#document-resource-object-relationships"
  end

  defp parse_relationships(relationships, _data), do: relationships

  defp parse_meta(%__MODULE__{} = resource_object, %{"meta" => meta}) when is_map(meta),
    do: %{resource_object | meta: meta}

  defp parse_meta(_resource_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Resource object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-objects"
  end

  defp parse_meta(resource_object, _data), do: resource_object
end
