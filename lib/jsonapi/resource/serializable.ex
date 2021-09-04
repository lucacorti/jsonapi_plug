defprotocol JSONAPI.Resource.Serializable do
  @moduledoc """
  JSONAPI Resource

  You can either provide an implementation directly

  ```elixir
  defmodule MyResource do
    defstruct id: nil, a: nil, b: [], c: :test

    defimpl JSONAPI.Resource.Serializable do
      def attributes(_resource): [:a, :c]
      def has_one(_resource), do: [b: MyOtherResourceView]
      def has_many(_resource), do: [d: MyDifferentResourceView]
    end
  end
  ```

  or derive the protocol by passing the configuration.

  ```elixir
  defmodule MyResource do
    @derive {JSONAPI.Resource.Serializable,
      attributes: [:a, :c],
      has_one: [b: MyOtherResourceView]
      has_many: [d: MyDifferentResourceView]
    }
    defstruct id: nil, a: nil, b: [], c: :test
  end
  ```
  """

  alias JSONAPI.{Resource.Field, View}

  @doc """
  Resource attributes

  Returns the resource attributes
  """
  @spec attributes(t()) :: [Field.name()]
  def attributes(resource)

  @doc """
  Resource one-to-one relationship

  Returns the resource one-to-one relationships
  """
  @spec has_one(t()) :: [{Field.name(), View.t()}]
  def has_one(resource)

  @doc """
  Resource one-to-many relationship

  Returns the resource one-to-many relationships
  """
  @spec has_many(t()) :: [{Field.name(), View.t()}]
  def has_many(resource)
end

defimpl JSONAPI.Resource.Serializable, for: Any do
  defmacro __deriving__(module, _struct, options) do
    attributes = Keyword.get(options, :attributes, [])
    has_one = Keyword.get(options, :has_one, [])
    has_many = Keyword.get(options, :has_many, [])

    quote do
      defimpl JSONAPI.Resource.Serializable, for: unquote(module) do
        def attributes(_resource), do: unquote(attributes)
        def has_one(_resource), do: unquote(has_one)
        def has_many(_resource), do: unquote(has_many)
      end
    end
  end

  def attributes(_resource), do: []
  def has_one(_resource), do: []
  def has_many(_resource), do: []
end
