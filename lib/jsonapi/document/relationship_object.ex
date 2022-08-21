defmodule JSONAPI.Document.RelationshipObject do
  @moduledoc """
  JSON:API Relationship Object

  https://jsonapi.org/format/#document-resource-object-relationships
  """

  alias JSONAPI.{
    Document,
    Document.LinkObject,
    Document.ResourceIdentifierObject,
    Exceptions.InvalidDocument
  }

  @type links :: %{atom() => LinkObject.t()}

  @type t :: %__MODULE__{
          data: ResourceIdentifierObject.t() | [ResourceIdentifierObject.t()] | nil,
          links: links() | nil,
          meta: Document.meta() | nil
        }

  defstruct [:data, :links, :meta]

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{}
    |> deserialize_data(data)
    |> deserialize_links(data)
    |> deserialize_meta(data)
  end

  defp deserialize_data(relationship_object, %{"data" => resource_identifier})
       when is_map(resource_identifier),
       do: %__MODULE__{
         relationship_object
         | data: ResourceIdentifierObject.deserialize(resource_identifier)
       }

  defp deserialize_data(relationship_object, %{"data" => resource_identifiers})
       when is_list(resource_identifiers),
       do: %__MODULE__{
         relationship_object
         | data: Enum.map(resource_identifiers, &ResourceIdentifierObject.deserialize/1)
       }

  defp deserialize_data(relationship_object, _data), do: relationship_object

  defp deserialize_links(relationship_object, %{"links" => links}),
    do: %__MODULE__{
      relationship_object
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.deserialize(link)}
          end)
    }

  defp deserialize_links(relationship_object, _data), do: relationship_object

  defp deserialize_meta(relationship_object, %{"meta" => meta}) when is_map(meta),
    do: %__MODULE__{relationship_object | meta: meta}

  defp deserialize_meta(_relationship_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Relationship object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-object-relationships"
  end

  defp deserialize_meta(relationship_object, _data), do: relationship_object
end
