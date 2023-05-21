defprotocol JSONAPIPlug.Resource.Links do
  alias JSONAPIPlug.Document
  alias Plug.Conn

  @fallback_to_any true

  @spec links(t(), Conn.t()) :: Document.links()
  def links(_t, _conn)
end

defimpl JSONAPIPlug.Resource.Links, for: Any do
  def links(_t, _conn), do: %{}
end
