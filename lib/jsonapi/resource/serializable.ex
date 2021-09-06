defprotocol JSONAPI.Resource.Serializable do
  @moduledoc """
  JSONAPI Resource

  You can either provide an implementation directly

  ```elixir
  defmodule MyResource do
    defstruct id: nil, a: nil, b: [], c: :test

    defimpl JSONAPI.Resource.Serializable do
      def attributes(_resource): [a: nil, x: :c]
      def relationships(_resource), do: [b: MyOtherResourceView, d: [MyDifferentResourceView]]
    end
  end
  ```

  or derive the protocol by passing the configuration.

  ```elixir
  defmodule MyResource do
    @derive {JSONAPI.Resource.Serializable,
      attributes: [a: nil, x: :c],
      relationships: [b: MyOtherResourceView, d: [MyDifferentResourceView]]
    }
    defstruct id: nil, a: nil, b: [], c: :test
  end
  ```
  """

  alias JSONAPI.{Resource.Field, Resource}

  @type attribute_opts :: [to: Field.name()]
  @type relationship_opts :: [many: boolean(), to: Field.name(), type: Resource.module_name()]

  @doc """
  Resource id attribute

  Returns the attribute to use as JSONAPI Resource ID
  """
  @spec id_attribute(Resource.t()) :: Field.name()
  def id_attribute(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Type
  """
  @spec type(Resource.t()) :: Resource.type()
  def type(resource)

  @doc """
  Resource attributes

  Returns the resource attributes
  """
  @spec attributes(t()) :: [Field.name()] | [{Field.name(), attribute_opts()}]
  def attributes(resource)

  @doc """
  Resource one-to-one relationship

  Returns the resource one-to-one relationships
  """
  @spec relationships(t()) :: [{Field.name(), relationship_opts()}]
  def relationships(resource)
end

defimpl JSONAPI.Resource.Serializable, for: Any do
  defmacro __deriving__(module, _struct, options) do
    id_attribute = Keyword.get(options, :id)
    type = Keyword.get(options, :type)
    attributes = Keyword.get(options, :attributes, [])
    relationships = Keyword.get(options, :relationships, [])

    quote do
      defimpl JSONAPI.Resource.Serializable, for: unquote(module) do
        if is_nil(unquote(id_attribute)) do
          raise "Resources must have an id attribute defined"
        else
          def id_attribute(resource), do: unquote(id_attribute)
        end

        if is_nil(unquote(type)) do
          raise "Resources must have a type defined"
        else
          def type(_resource), do: unquote(type)
        end

        def attributes(_resource), do: unquote(attributes)
        def relationships(_resource), do: unquote(relationships)
      end
    end
  end

  def id_attribute(_resource), do: raise("Resources must have an id defined")
  def type(_resource), do: raise("Resources must have a type defined")
  def attributes(_resource), do: []
  def relationships(_resource), do: []
end
