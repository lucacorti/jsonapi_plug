defmodule JSONAPI.Resource do
  @moduledoc """
  JSONAPI Resource

  `JSONAPI.Resource` relies on the `JSONAPI.Resource.Identifiable` and `JSONAPI.Resource.Serializable`
  protocols to provide Resource related functionality.
  """

  alias JSONAPI.{Resource.Identifiable, Resource.Serializable, View}

  @typedoc "JSONAPI Resource"
  @type t :: struct()

  @typedoc "Resource attribute"
  @type attribute :: atom()

  @typedoc "Resource type"
  @type options :: [type: module()]

  @typedoc "Resource ID"
  @type id :: String.t()

  @typedoc "Resource Type"
  @type type :: String.t()

  @doc """
  Resource id

  Returns the JSONAPI Resource ID
  """
  @spec id(t()) :: id()
  def id(resource), do: to_string(Identifiable.id(resource))

  @doc """
  Resource type

  Returns the JSONAPI Resource Type
  """
  @spec type(t()) :: id()
  def type(resource), do: to_string(Identifiable.type(resource))

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  @spec attributes(t()) :: [attribute()]
  def attributes(resource), do: Serializable.attributes(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  @spec has_one(t()) :: [{attribute(), View.t()}]
  def has_one(resource),
    do: Serializable.has_one(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  @spec has_many(t()) :: [{attribute(), View.t()}]
  def has_many(resource),
    do: Serializable.has_one(resource)
end
