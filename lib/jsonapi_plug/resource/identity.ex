defprotocol JSONAPIPlug.Resource.Identity do
  alias JSONAPIPlug.Resource

  @spec client_generated_ids?(t()) :: boolean()
  def client_generated_ids?(t)

  @spec id_attribute(t()) :: Resource.field_name()
  def id_attribute(t)

  @spec type(t()) :: Resource.type()
  def type(t)
end

defimpl JSONAPIPlug.Resource.Identity, for: Any do
  alias JSONAPIPlug.Resource

  def client_generated_ids?(_t), do: false

  def id_attribute(_t), do: :id

  def type(%module{} = t),
    do: Resource.field_recase(t, Module.split(module) |> List.last())
end
