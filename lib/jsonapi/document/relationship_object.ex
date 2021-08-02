defmodule JSONAPI.Document.RelationshipObject do
  @moduledoc """
  JSON:API Relationship Object

  See https://jsonapi.org/format/#document-resource-object-relationships
  """

  alias JSONAPI.{Document, Resource, View}
  alias Plug.Conn

  @type data :: %{type: Resource.type(), id: Resource.id()}

  @type t :: %__MODULE__{
          data: data() | [data()],
          links: Document.links() | nil,
          meta: Document.meta() | nil
        }

  defstruct data: nil, links: nil, meta: nil

  @spec serialize(View.t(), Resource.t() | [Resource.t()], String.t(), Conn.t() | nil) :: t()
  def serialize(rel_view, rel_data, rel_url, conn) do
    %__MODULE__{
      data: serialize_data(rel_view, rel_data),
      links: %{self: rel_url, related: rel_view.url_for(rel_data, conn)}
    }
  end

  defp serialize_data(_view, nil), do: nil

  defp serialize_data(view, resources) when is_list(resources),
    do: Enum.map(resources, &serialize_data(view, &1))

  defp serialize_data(view, resource), do: %{id: view.id(resource), type: view.type()}
end
