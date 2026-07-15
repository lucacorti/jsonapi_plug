defprotocol JSONAPIPlug.Resource do
  @moduledoc """
  You can use any struct as a resource by deriving or directly implementing the `JSONAPIPlug.Resource` protocol:

  ```elixir
  defmodule MyApp.User do
    @derive {
      JSONAPIPlug.Resource,
      type: "user",
      attributes: [:name, :surname, :username]
    }
    defstruct id: nil, name: nil, surname: nil, username: nil
  end
  ```
  See `t:options/0` for all available options you can pass to `@derive JSONAPIPlug.Resource`.

  ## Attributes

  By default, the resulting JSON document consists of resources taken from your data.
  Only resource attributes defined on the resource will be (de)serialized. You can customize
  how attributes are handled by passing a keyword list of options:

  ```elixir
  defmodule MyApp.User do
    @derive {
      JSONAPIPlug.Resource,
      type: "user",
      attributes: [
        username: nil,
        fullname: [deserialize: false]
      ]
    }
  end
  ```

  In this example we are defining a computed attribute by passing the `serialize` option a function reference.
  Serialization functions take `resource` and `conn` as arguments and return the attribute value to be serialized.
  The `deserialize` option set to `false` makes sure the attribute is not deserialized when receiving a request.

  ## Relationships

  Relationships are defined by passing the `relationships` option to `use JSONAPIPlug.Resource`.

  ```elixir
  defmodule MyApp.Post do
    @derive {
      JSONAPIPlug.Resource,
      type: "post",
      attributes: [:text, :body]
      relationships: [
        author: [resource: MyApp.UsersResource],
        comments: [many: true, resource: MyApp.CommentsResource]
      ]
    }
  end

  defmodule MyApp.CommentsResource do
    alias MyApp.UsersResource

    @derive {
      JSONAPIPlug.Resource,
      type: "comment",
      attributes: [:text]
      relationships: [post: [resource: MyApp.Post]]
    }
    defstruct text: nil, post: nil
  end
  ```

  When requesting `GET /posts?include=author`, if the author key is present on the data you pass from the
  controller it will appear in the `included` section of the JSON:API response.

  ## Links

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. If you need to use different values for some reason, you can override them
  using `JSONAPIPlug.API` configuration options in your api configuration:

  ```elixir
  config :my_app, MyApp.API, host: "adifferenthost.com"
  ```
  """

  alias JSONAPIPlug.Document.ResourceObject

  @typedoc """
  Resource module

  A struct implementing the `JSONAPIPlug.Resource` protocol
  """
  @type t :: struct()

  @typedoc """
  Resource options

  Available options:
  #{NimbleOptions.docs(JSONAPIPlug.resource_options_schema())}
  """
  @type options :: keyword()

  @typedoc """
  Resource field name

  The name of a Resource field (attribute or relationship)
  """
  @type field_name :: atom()

  @doc "Returns the resource attributes"
  @spec attributes(t()) :: [field_name()]
  def attributes(resource)

  @doc """
  Resource Id Attribute

  Returns the attribute used to fetch resource ids for resources by the
  """
  @spec id_attribute(t()) :: field_name()
  def id_attribute(resource)

  @doc """
  Resource field option

  Returns the value of the requested field option
  """
  @spec field_option(t(), field_name(), atom()) :: term()
  def field_option(resource, field_name, option)

  @doc """
  Resource function to recase fields

  Returns the field is the required case
  """
  @spec recase_field(t(), field_name(), JSONAPIPlug.case()) :: String.t()
  def recase_field(resource, field_name, jsonapi_plug)

  @doc """
  Resource relationships

  Returns the keyword list of resource relationships for the
  """
  @spec relationships(t()) :: [field_name()]
  def relationships(resource)

  @doc """
  Resource schema

  Returns an ExJsonSchema used to validate resource attributes.
  """
  @spec schema(t()) :: term()
  def schema(resource)

  @doc """
  Resource Type

  Returns the Resource Type of resources for the
  """
  @spec type(t()) :: ResourceObject.type()
  def type(resource)
end

defimpl JSONAPIPlug.Resource, for: Any do
  defmacro __deriving__(module, _struct, options) do
    options =
      options
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> Keyword.update(:attributes, [], fn attributes ->
        Enum.map(attributes, fn
          {field_name, nil} -> {field_name, []}
          {field_name, field_options} -> {field_name, field_options}
          field_name -> {field_name, []}
        end)
      end)
      |> NimbleOptions.validate!(JSONAPIPlug.resource_options_schema())

    attributes = generate_attributes(options)
    relationships = generate_relationships(options)

    check_fields(attributes, relationships, options)

    field_option = generate_field_option(options)
    recase_field = generate_recase_field(attributes, relationships)
    schema = generate_schema(options)

    quote do
      defimpl JSONAPIPlug.Resource, for: unquote(module) do
        def id_attribute(_resource), do: unquote(options[:id_attribute] || :id)
        def attributes(_resource), do: unquote(attributes)

        unquote(
          Enum.reverse([
            quote do
              def field_option(_resource, _field_name, _field_option), do: nil
            end
            | field_option
          ])
        )

        def path(_resource), do: unquote(options[:path])
        unquote(recase_field)
        def relationships(_resource), do: unquote(relationships)
        def schema(_resource), do: unquote(schema)
        def type(_resource), do: unquote(options[:type])
      end
    end
  end

  defp generate_attributes(options) do
    Enum.map(options[:attributes] || [], fn {attribute, _options} -> attribute end)
  end

  defp generate_relationships(options) do
    Enum.map(options[:relationships] || [], fn {relationship, _options} -> relationship end)
  end

  defp check_fields(attributes, relationships, options) do
    for field_name <- attributes do
      if field_name in [:id, :type] do
        raise "Illegal attribute name '#{field_name}' for resource '#{options[:type]}'. See https://jsonapi.org/format/#document-resource-object-fields for more information."
      end
    end

    for field_name <- relationships do
      if field_name in [:id, :type] do
        raise "Illegal relationship name '#{field_name}' for resource '#{options[:type]}'. See https://jsonapi.org/format/#document-resource-object-fields for more information."
      end
    end
  end

  defp generate_field_option(options) do
    Stream.concat(options[:attributes], options[:relationships])
    |> Enum.flat_map(fn {field_name, field_options} ->
      Enum.map(field_options, fn {field_option, value} ->
        quote do
          def field_option(_resource, unquote(field_name), unquote(field_option)),
            do: unquote(value)
        end
      end)
    end)
  end

  defp generate_recase_field(attributes, relationships) do
    Stream.concat(attributes, relationships)
    |> Enum.flat_map(fn field_name ->
      Enum.map([:camelize, :dasherize, :underscore], fn field_case ->
        recased = JSONAPIPlug.recase(field_name, field_case)

        quote do
          def recase_field(_resource, unquote(field_name), unquote(field_case)),
            do: unquote(recased)

          def recase_field(_resource, unquote(to_string(field_name)), unquote(field_case)),
            do: unquote(recased)
        end
      end)
    end)
  end

  def generate_schema(options) do
    %{
      "type" => "object",
      "required" =>
        Enum.reduce(options[:attributes], [], fn {attribute, options}, required ->
          (options[:required] && [to_string(options[:name] || attribute) | required]) || required
        end),
      "properties" =>
        Enum.into(options[:attributes], %{}, fn {attribute, options} ->
          {
            to_string(options[:name] || attribute),
            %{"type" => to_string(options[:type] || :string)}
          }
        end)
    }
    |> ExJsonSchema.Schema.resolve()
    |> Macro.escape()
  end

  def id_attribute(_resource), do: :id
  def attributes(_resource), do: []
  def field_name(_resource, field_name), do: field_name
  def field_option(_resource, _field_name, _option), do: nil
  def path(_resource), do: nil
  def recase_field(_resource, field, _case), do: field
  def relationships(_resource), do: []
  def schema(_resource), do: nil
  def type(_resource), do: ""
end
