defprotocol JSONAPIPlug.Resource.Attribute do
  @moduledoc """
  Custom Resource attributes serialization and deserialization

  This protocol allows to customize how individual resource attributes
  are serialized to in responses and deserialized from requests.

  The default implementation serializes and deserializes  attributes as
  they appear in the resource.

  The implementation for `MyApp.Post` below, serializes the excerpt
  attribute by taking the first 10 characters of the post body value,
  and preserves all other attributes values in other cases.

  ```elixir
  defimpl JSONAPIPlug.Resource.Attribute, for: MyApp.Post do
    def serialize(%@for{}, :excerpt, _value, _conn),
      do: String.slice(post.body, 0..9)

    def serialize(%@for{}, :excerpt, _value, _conn), do: value

    def deserialize(%@for{}, :excerpt, _value, _conn), do: value
  end
  ```
  """
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
