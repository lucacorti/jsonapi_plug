defprotocol JSONAPIPlug.Resource.Meta do
  @moduledoc """
  Resource Links

  Implement this protocol to generate JSON:API metadata for indivudual resources.
  """

  alias JSONAPIPlug.{Document, Resource}
  alias Plug.Conn

  @fallback_to_any true

  @doc """
  Resource meta

  Returns the resource meta to be returned for resources by the resource.
  """
  @spec meta(Resource.t(), Conn.t()) :: Document.meta() | nil
  def meta(resource, conn)
end

defimpl JSONAPIPlug.Resource.Meta, for: Any do
  def meta(_resource, _conn), do: nil
end
