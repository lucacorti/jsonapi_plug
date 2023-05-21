defprotocol JSONAPIPlug.Resource.Meta do
  alias JSONAPIPlug.Document
  alias Plug.Conn

  @fallback_to_any true

  @spec meta(t(), Conn.t()) :: Document.meta()
  def meta(_t, _conn)
end

defimpl JSONAPIPlug.Resource.Meta, for: Any do
  def meta(_t, _conn), do: %{}
end
