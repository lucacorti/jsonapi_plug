defprotocol JSONAPIPlug.Resource.Attribute do
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  @fallback_to_any true

  @spec render(Resource.t(), Resource.field_name(), Conn.t()) :: term()
  def render(resource, field_name, conn)
end

defimpl JSONAPIPlug.Resource.Attribute, for: Any do
  def render(resource, field_name, _conn), do: Map.get(resource, field_name)
end
