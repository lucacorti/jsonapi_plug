defprotocol JSONAPIPlug.Resource.Attribute do
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  @fallback_to_any true

  @doc "Customize serialization of resource attribute value in the response"
  @spec serialize(Resource.t(), Resource.field_name(), term(), Conn.t()) :: term()
  def serialize(resource, field_name, value, conn)

  @doc "Customize deserialization of resource attribute value from the request"
  @spec deserialize(Resource.t(), Resource.field_name(), term(), Conn.t()) :: term()
  def deserialize(resource, field_name, value, conn)
end

defimpl JSONAPIPlug.Resource.Attribute, for: Any do
  def serialize(_resource, _attribute, value, _conn), do: value
  def deserialize(_resource, _attribute, value, _conn), do: value
end
