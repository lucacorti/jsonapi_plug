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

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) do
    %__MODULE__{
      data: deserialize_data(data),
      links: deserialize_links(data),
      meta: deserialize_meta(data)
    }
  end

  defp deserialize_data(%{"data" => resource_identifier})
       when is_map(resource_identifier),
       do: ResourceIdentifierObject.deserialize(resource_identifier)

  defp deserialize_data(%{"data" => resource_identifiers})
       when is_list(resource_identifiers),
       do: Enum.map(resource_identifiers, &ResourceIdentifierObject.deserialize/1)

  defp deserialize_data(_data), do: nil

  defp deserialize_links(%{"links" => links}),
    do:
      Enum.into(links, %{}, fn {name, link} ->
        {name, LinkObject.deserialize(link)}
      end)

  defp deserialize_links(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta),
    do: meta

  defp deserialize_meta(%{"meta" => _meta}) do
    raise InvalidDocument,
      message: "Relationship object 'meta' must be an object",
      reference: "https://jsonapi.org/format/#document-resource-object-relationships"
  end

  defp deserialize_meta(_data), do: nil
end
