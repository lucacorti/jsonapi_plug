defmodule JSONAPIPlug.Document.RelationshipObject do
  @moduledoc """
  JSON:API Relationship Object

  https://jsonapi.org/format/#document-resource-object-relationships
  """

  alias JSONAPIPlug.{
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

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) do
    %__MODULE__{}
    |> parse_data(data)
    |> parse_links(data)
    |> parse_meta(data)
  end

  defp parse_data(%__MODULE__{} = relationship_object, %{"data" => resource_identifier})
       when is_map(resource_identifier),
       do: %{
         relationship_object
         | data: ResourceIdentifierObject.parse(resource_identifier)
       }

  defp parse_data(%__MODULE__{} = relationship_object, %{"data" => resource_identifiers})
       when is_list(resource_identifiers),
       do: %{
         relationship_object
         | data: Enum.map(resource_identifiers, &ResourceIdentifierObject.parse/1)
       }

  defp parse_data(relationship_object, _data), do: relationship_object

  defp parse_links(%__MODULE__{} = relationship_object, %{"links" => links}),
    do: %{
      relationship_object
      | links:
          Enum.into(links, %{}, fn {name, link} ->
            {name, LinkObject.parse(link)}
          end)
    }

  defp parse_links(relationship_object, _data), do: relationship_object

  defp parse_meta(%__MODULE__{} = relationship_object, %{"meta" => meta}) when is_map(meta),
    do: %{relationship_object | meta: meta}

  defp parse_meta(_relationship_object, %{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Relationship object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-object-relationships"
  end

  defp parse_meta(relationship_object, _data), do: relationship_object
end
