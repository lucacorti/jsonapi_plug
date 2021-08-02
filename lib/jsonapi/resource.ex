defmodule JSONAPI.Resource do
  @moduledoc """
  JSONAPI Resource

  `JSONAPI.Resource` relies on the `JSONAPI.Resource.Identifiable` and `JSONAPI.Resource.Serializable`
  protocols to provide Resource related functionality.
  """

  alias JSONAPI.Resource.{Identifiable, Serializable}

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
  def type(resource), do: Identifiable.type(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  def attributes(resource), do: Serializable.attributes(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  def has_one(resource),
    do: Serializable.has_one(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Attributes
  """
  def has_many(resource),
    do: Serializable.has_one(resource)
end
