defmodule JSONAPI.Document.RelationshipObject do
  @moduledoc """
  JSON:API Relationship Object

  https://jsonapi.org/format/#relationship-resource-object-relationships
  """

  alias JSONAPI.{Document, Document.LinksObject, Resource, View}
  alias Plug.Conn

  @type data :: %{id: Resource.id(), type: Resource.type()}

  @type t :: %__MODULE__{
          data: data() | [data()] | nil,
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

  defp relationship_data(view, resource), do: %{id: view.id(resource), type: view.type()}

  defp serialize_links(%__MODULE__{} = relationship, view, resources, conn, url) do
    %__MODULE__{relationship | links: %{self: url, related: View.url_for(view, resources, conn)}}
  end

  defp serialize_meta(%__MODULE__{} = relationship, meta) when is_map(meta),
    do: %__MODULE__{relationship | meta: meta}

  defp serialize_meta(relationship, _meta), do: relationship

  @spec deserialize(View.t(), Document.payload()) :: t()
  def deserialize(view, payload) do
    %__MODULE__{}
    |> deserialize_data(view, payload)
  end

  defp deserialize_data(relationship_object, _view, %{"data" => %{"id" => id, "type" => type}}) do
    %__MODULE__{relationship_object | data: %{id: id, type: type}}
  end

  defp deserialize_data(relationship_object, _view, _payload), do: relationship_object
end
