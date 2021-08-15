defmodule JSONAPI.Resource do
  @moduledoc """
  JSONAPI Resource

  `JSONAPI.Resource` relies on the `JSONAPI.Resource.Identifiable` and `JSONAPI.Resource.Serializable`
  protocols to provide Resource related functionality.
  """

  alias JSONAPI.{Resource.Identifiable, Resource.Loadable, Resource.Serializable, View}

  @typedoc "Resource"
  @type t :: struct()

  @typedoc "Resource ID"
  @type id :: String.t()

  @typedoc "Resource field"
  @type field :: atom()

  @typedoc "Resource Type"
  @type type :: String.t()

  @doc """
  Resource id

  Returns the JSON:API Resource ID
  """
  @spec id(t()) :: id()
  def id(resource), do: to_string(Identifiable.id(resource))

  @doc """
  Resource type

  Returns the JSON:API Resource Type
  """
  @spec type(t()) :: id()
  def type(resource), do: to_string(Identifiable.type(resource))

  @doc """
  Resource type

  Returns the JSON:API Resource Attributes
  """
  @spec attributes(t()) :: [field()]
  def attributes(resource), do: Serializable.attributes(resource)

  @doc """
  Resource type

  Returns the JSON:API Resource One-to-One relationships
  """
  @spec has_one(t()) :: [{field(), View.t()}]
  def has_one(resource),
    do: Serializable.has_one(resource)

  @doc """
  Resource type

  Returns the JSON:API Resource One-to-Many relationships
  """
  @spec has_many(t()) :: [{field(), View.t()}]
  def has_many(resource),
    do: Serializable.has_one(resource)

  @doc """
  Resource loaded

  Returns a boolean indicating wether the given Resource is loaded
  """
  @spec loaded?(t()) :: boolean()
  def loaded?(resource), do: Loadable.loaded?(resource)
end
