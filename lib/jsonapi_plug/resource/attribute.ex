defprotocol JSONAPIPlug.Resource.Attribute do
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  @fallback_to_any true

  @doc "Customize rendering of resource attribute value in responses"
  @spec render(Resource.t(), Resource.field_name(), Conn.t()) :: term()
  def render(resource, field_name, conn)

  @doc "Customize parsing of resource attribute value from requests"
  @spec parse(Resource.t(), Resource.field_name(), term(), Conn.t()) :: term()
  def parse(resource, field_name, value, conn)
end

defimpl JSONAPIPlug.Resource.Attribute, for: Any do
  def render(resource, attribute, _conn), do: Map.get(resource, attribute)
  def parse(_resource, _attribute, value, _conn), do: value
end
