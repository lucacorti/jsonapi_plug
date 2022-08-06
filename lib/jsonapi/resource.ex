defprotocol JSONAPI.Resource do
  @moduledoc """
  JSON:API Resource
  """

  @type t :: any()
  @type id :: String.t()
  @type field :: atom()
  @type type :: String.t()

  @fallback_to_any true

  @spec loaded?(t()) :: boolean()
  def loaded?(resource)
end

defimpl JSONAPI.Resource, for: Ecto.Association.NotLoaded do
  def loaded?(_resource), do: false
end

defimpl JSONAPI.Resource, for: Atom do
  def loaded?(nil = _atom), do: false
  def loaded?(_atom), do: true
end

defimpl JSONAPI.Resource, for: Any do
  def loaded?(_resource), do: true
end
