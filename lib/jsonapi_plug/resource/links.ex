defprotocol JSONAPIPlug.Resource.Links do
  @moduledoc """
  Resource Links

  Implement this protocol to generate JSON:API links for individual resources.
  """

  alias JSONAPIPlug.{Document, Resource}
  alias Plug.Conn

  @fallback_to_any true
  @doc """
  Resource links

  Returns the resource links to be returned for resources by the resource.
  """
  @spec links(Resource.t(), Conn.t() | nil) :: Document.links()
  def links(resource, conn)
end

defimpl JSONAPIPlug.Resource.Links, for: Any do
  def links(_resource, _conn), do: %{}
end
