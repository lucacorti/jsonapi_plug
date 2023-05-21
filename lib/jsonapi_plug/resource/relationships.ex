defprotocol JSONAPIPlug.Resource.Relationships do
  alias JSONAPIPlug.Resource

  @spec relationships(t()) :: keyword(Resource.relationship_options())
  def relationships(t)
end

defimpl JSONAPIPlug.Resource.Relationships, for: Any do
  def relationships(_t), do: []
end
