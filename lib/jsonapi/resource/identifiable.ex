defprotocol JSONAPI.Resource.Identifiable do
  @moduledoc """
  JSONAPI Resource

  You can either provide an implementation directly

  ```elixir
  defmodule MyResource do
    defstruct id: nil, a: nil, b: [], c: :test

    defimpl JSONAPI.Resource.Identifiable do
      def id_attribute(_resource), do: :id
      def type(_resource), do: "my-resource"
    end
  end
  ```

  or derive the protocol by passing the configuration.

  ```elixir
  defmodule MyResource do
    @derive {JSONAPI.Resource.Identifiable, type: "my-resource", id_attribute: :id}
    defstruct id: nil, a: nil, b: [], c: :test
  end
  ```
  """

  alias JSONAPI.Resource

  @doc """
  Resource id attribute

  Returns the attribute to use as JSONAPI Resource ID
  """
  @spec id_attribute(Resource.t()) :: Resource.field()
  def id_attribute(resource)

  @doc """
  Resource type

  Returns the JSONAPI Resource Type
  """
  @spec type(Resource.t()) :: Resource.type()
  def type(resource)
end

defimpl JSONAPI.Resource.Identifiable, for: Any do
  defmacro __deriving__(module, _struct, options) do
    id_attribute = Keyword.get(options, :id_attribute)
    type = Keyword.get(options, :type)

    quote do
      defimpl JSONAPI.Resource.Identifiable, for: unquote(module) do
        if is_nil(unquote(id_attribute)) do
          raise "Resources must have an id_attribute defined"
        else
          def id_attribute(resource), do: unquote(id_attribute)
        end

        if is_nil(unquote(type)) do
          raise "Resources must have a type defined"
        else
          def type(_resource), do: unquote(type)
        end
      end
    end
  end

  def id_attribute(_resource), do: raise("Resources must have an id defined")
  def type(_resource), do: raise("Resources must have a type defined")
end
