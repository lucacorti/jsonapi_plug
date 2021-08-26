defmodule JSONAPI.Document.RelationshipObject do
  @moduledoc """
  JSON:API Relationship Object

  https://jsonapi.org/format/#document-resource-object-relationships
  """

  alias JSONAPI.{Document, Document.LinksObject, Document.ResourceLinkage, View}
  alias Plug.Conn

  @type t :: %__MODULE__{
          data: ResourceLinkage.t() | [ResourceLinkage.t()] | nil,
          links: Document.links() | nil,
          meta: Document.meta() | nil
        }

  defstruct [:data, :links, :meta]

  @spec serialize(View.t(), View.data() | nil, Conn.t() | nil, LinksObject.link()) :: t()
  def serialize(view, resources, conn, url) do
    %__MODULE__{}
    |> serialize_data(view, resources)
    |> serialize_links(view, resources, conn, url)
    |> serialize_meta(view.meta(resources, conn))
  end

  defp serialize_data(%__MODULE__{} = relationship, view, resources) when is_list(resources),
    do: %__MODULE__{relationship | data: Enum.map(resources, &relationship_data(view, &1))}

  defp serialize_data(%__MODULE__{} = relationship, view, resource),
    do: %__MODULE__{relationship | data: relationship_data(view, resource)}

  defp relationship_data(view, resource),
    do: %ResourceLinkage{id: view.id(resource), type: view.type()}

  defp serialize_links(%__MODULE__{} = relationship, view, resources, conn, url) do
    %__MODULE__{relationship | links: %{self: url, related: View.url_for(view, resources, conn)}}
  end

  defp serialize_meta(%__MODULE__{} = relationship, meta) when is_map(meta),
    do: %__MODULE__{relationship | meta: meta}

  defp serialize_meta(relationship, _meta), do: relationship
end
