defprotocol JSONAPIPlug.Resource.Fields do
  alias JSONAPIPlug.Resource

  @spec attributes(t()) :: keyword(Resource.attribute_options() | nil)
  def attributes(t)

  @spec fields_case(t()) :: Resource.field_case()
  def fields_case(t)

  @spec relationships(t()) :: keyword(Resource.relationship_options())
  def relationships(t)
end

defimpl JSONAPIPlug.Resource.Fields, for: Any do
  def attributes(_t), do: []
  def fields_case(_t), do: :camelize
  def relationships(_t), do: []
end
