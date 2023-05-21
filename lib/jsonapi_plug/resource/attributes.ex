defprotocol JSONAPIPlug.Resource.Attributes do
  alias JSONAPIPlug.Resource

  @spec attributes(t()) :: keyword(Resource.attribute_options() | nil)
  def attributes(t)
end

defimpl JSONAPIPlug.Resource.Attributes, for: Any do
  def attributes(_t), do: []
end
