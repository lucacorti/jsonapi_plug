defprotocol JSONAPIPlug.Resource.Identity do
  alias JSONAPIPlug.Resource

  @spec id_attribute(t()) :: Resource.field_name()
  def id_attribute(t)

  @spec type(t()) :: Resource.type()
  def type(t)
end

defimpl JSONAPIPlug.Resource.Identity, for: Any do
  alias JSONAPIPlug.Resource

  def id_attribute(_t), do: :id

  def type(%module{}),
    do: Module.split(module) |> List.last() |> Resource.field_recase(:dasherize)
end
