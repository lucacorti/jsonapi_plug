defmodule JSONAPI.Resource do
  @moduledoc """
  JSONAPI Resource functions

  `JSONAPI.Resource` relies on the `JSONAPI.Resource.Serializable` protocol to
  be able to translate resources to and from JSON:API wire format.
  """

  alias JSONAPI.Field
  alias JSONAPI.Resource.{Field, Loadable, Serializable}
  alias JSONAPI.{Document, Resource}

  @typedoc "Resource"
  @type t :: struct()

  @typedoc "Module"
  @type module_name :: module()

  @typedoc "Resource ID"
  @type id :: String.t()

  @typedoc "Resource Type"
  @type type :: String.t()

  @doc """
  Resource id

  Returns the JSON:API Resource ID
  """
  @spec id(t()) :: id()
  def id(resource) do
    case Map.fetch(resource, Serializable.id_attribute(resource)) do
      {:ok, id} -> to_string(id)
      :error -> raise "Resources must have and id defined"
    end
  end

  @doc """
  Resource type

  Returns the JSON:API Resource Type
  """
  @spec type(t()) :: type()
  def type(resource), do: to_string(Serializable.type(resource))

  @doc """
  Resource type

  Returns the JSON:API Resource Attributes
  """
  @spec attributes(t()) :: [Field.name() | {Field.name(), Field.name() | nil}]
  def attributes(resource), do: Serializable.attributes(resource)

  @spec deserialize(t(), Document.payload(), [t()]) :: t()
  def deserialize(resource, %{"id" => id} = data, included) do
    resource
    |> deserialize_attributes(data)
    |> deserialize_relationships(data, included)
    |> struct(Keyword.put([], Serializable.id_attribute(resource), id))
  end

  defp deserialize_attributes(resource, %{"attributes" => attributes})
       when is_map(attributes) do
    attrs =
      resource
      |> Resource.attributes()
      |> Enum.map(fn attribute ->
        {from, to} = map_attribute(attribute)

        case Map.fetch(attributes, to_string(from)) do
          {:ok, value} ->
            {to, value}

          :error ->
            {to, %Field.NotLoaded{field: from}}
        end
      end)

    struct(resource, attrs)
  end

  defp deserialize_attributes(resource, _data), do: resource

  defp map_attribute(key) when is_atom(key), do: {key, key}
  defp map_attribute({key, nil}), do: {key, key}
  defp map_attribute({key, []}), do: {key, key}
  defp map_attribute({key, options}), do: {key, Keyword.get(options, :to, key)}

  defp deserialize_relationships(resource, %{"relationships" => relationships}, included)
       when is_map(relationships) do
    attrs =
      resource
      |> Resource.relationships()
      |> Enum.map(fn {from, options} ->
        many = Keyword.get(options, :many, false)
        to = Keyword.get(options, :to, from)

        case Map.fetch(relationships, to_string(from)) do
          {:ok, value} when many == true ->
            {to, Enum.map(value, &deserialize_relationship(from, &1, included))}

          {:ok, value} ->
            {to, deserialize_relationship(from, value, included)}

          :error ->
            {to, %Field.NotLoaded{field: from}}
        end
      end)

    struct(resource, attrs)
  end

  defp deserialize_relationships(resource, _data, _included), do: resource

  defp deserialize_relationship(
         relationship,
         %{"data" => %{"id" => id, "type" => type}},
         included
       ) do
    resource =
      case Enum.find(included, fn resource ->
             id == Resource.id(resource) && type == Resource.type(resource)
           end) do
        nil -> %Field.NotLoaded{field: relationship, id: id, type: type}
        resource -> resource
      end

    {relationship, resource}
  end

  @doc """
  Resource type

  Returns the JSON:API Resource One-to-One relationships
  """
  @spec relationships(t()) :: [{Field.name(), Resource.module_name() | [Resource.module_name()]}]
  def relationships(resource), do: Serializable.relationships(resource)

  @doc """
  Resource loaded

  Returns a boolean indicating wether the given Resource is loaded
  """
  @spec loaded?(t()) :: boolean()
  def loaded?(resource), do: Loadable.loaded?(resource)
end
