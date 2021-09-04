defprotocol JSONAPI.Resource.Loadable do
  alias JSONAPI.Resource

  @fallback_to_any true

  @spec loaded?(Resource.t()) :: boolean()
  def loaded?(resource)
end

defimpl JSONAPI.Resource.Loadable, for: Ecto.Relationship.NotLoaded do
  def loaded?(_resource), do: false
end

defimpl JSONAPI.Resource.Loadable, for: Atom do
  def loaded?(nil = _atom), do: false
  def loaded?(_atom), do: true
end

defimpl JSONAPI.Resource.Loadable, for: List do
  def loaded?(_resource), do: true
end

defimpl JSONAPI.Resource.Loadable, for: Map do
  def loaded?(_resource), do: true
end

defimpl JSONAPI.Resource.Loadable, for: Any do
  def loaded?(_resource), do: true
end
