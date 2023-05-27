defprotocol JSONAPIPlug.Resource.Fields do
  alias JSONAPIPlug.Resource

  @spec attributes(t()) :: keyword(Resource.attribute_options() | nil)
  def attributes(t)

  @spec case(t()) :: Resource.field_case()
  def case(t)

  @spec relationships(t()) :: keyword(Resource.relationship_options())
  def relationships(t)
end

defimpl JSONAPIPlug.Resource.Fields, for: Any do
  def attributes(_t), do: []
  def case(_t), do: :camelize
  def relationships(_t), do: []
end
