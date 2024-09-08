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

  You can now call `JSONAPIPlug.render(conn, user)` to render a valid JSON:API document from
  your data. If you use `phoenix`, you can call this in your controller to render the response.

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
        fullname: [deserialize: false, serialize: &fullname/2]
      ]
    }
    defp fullname(resource, conn), do: "\#{resouce.first_name} \#{last_name}"
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

  @typedoc "Resource options"
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
  Resource Type

  Returns the Resource Type of resources for the
  """
  @spec type(t()) :: ResourceObject.type()
  def type(resource)
end

defimpl JSONAPIPlug.Resource, for: Any do
  @attribute_schema [
    name: [
      doc: "Maps the resource attribute name to the given key.",
      type: :atom
    ],
    serialize: [
      doc:
        "Can be either a boolean, a function reference or MFA returning the attribute value to be serialized.",
      type: {:or, [:boolean, {:fun, 2}, :mfa]},
      default: true
    ],
    deserialize: [
      doc:
        "Can be either a boolean, a function reference or MFA returning the attribute value to be deserialized.",
      type: {:or, [:boolean, {:fun, 2}, :mfa]},
      default: true
    ]
  ]

  @relationship_schema [
    name: [
      doc: "Maps the resource relationship name to the given key.",
      type: :atom
    ],
    many: [
      doc: "Specifies a to many relationship.",
      type: :boolean,
      default: false
    ],
    resource: [
      doc: "Specifies the resource to be used to serialize the relationship",
      type: :atom,
      required: true
    ]
  ]

  @schema NimbleOptions.new!(
            attributes: [
              doc:
                "Resource attributes. This will be used to (de)serialize requests/responses:\n\n" <>
                  NimbleOptions.docs(@attribute_schema, nest_level: 1),
              type:
                {:or,
                 [
                   {:list, :atom},
                   {:keyword_list, [*: [type: [keyword_list: [keys: @attribute_schema]]]]}
                 ]},
              default: []
            ],
            id_attribute: [
              doc: "Attribute on your data to be used as the JSON:API resource id.",
              type: :atom,
              default: :id
            ],
            path: [
              doc: "A custom path to be used for the  Defaults to the resource type.",
              type: :string
            ],
            relationships: [
              doc:
                "Resource relationships. This will be used to (de)serialize requests/responses\n\n" <>
                  NimbleOptions.docs(@relationship_schema, nest_level: 1),
              type: :keyword_list,
              keys: [*: [type: :non_empty_keyword_list, keys: @relationship_schema]],
              default: []
            ],
            type: [
              doc: "Resource type. To be used as the JSON:API resource type value",
              type: :string,
              required: true
            ]
          )

  @doc """
  Resource options

  #{NimbleOptions.docs(@schema)}
  """
  defmacro __deriving__(module, _struct, options) do
    options =
      options
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(@schema)

    attributes = generate_attributes(options)
    relationships = generate_relationships(options)

    check_fields(attributes, relationships, options)

    field_option = generate_field_option(options)
    recase_field = generate_recase_field(options)

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
        def type(_resource), do: unquote(options[:type])
      end
    end
  end

  defp generate_attributes(options) do
    Enum.map(options[:attributes] || [], fn
      {field_name, _field_options} -> field_name
      field_name -> field_name
    end)
  end

  defp generate_relationships(options) do
    Enum.map(options[:relationships] || [], fn
      {field_name, _field_options} -> field_name
      field_name -> field_name
    end)
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
    |> Stream.map(fn
      {field_name, nil} -> {field_name, []}
      {field_name, field_options} -> {field_name, field_options}
      field_name -> {field_name, []}
    end)
    |> Enum.flat_map(fn {field_name, field_options} ->
      Enum.map(field_options, fn {field_option, value} ->
        quote do
          def field_option(_resource, unquote(field_name), unquote(field_option)),
            do: unquote(value)
        end
      end)
    end)
  end

  defp generate_recase_field(options) do
    Stream.concat(options[:attributes], options[:relationships])
    |> Stream.map(fn
      {field_name, _field_options} -> field_name
      field_name -> field_name
    end)
    |> Enum.flat_map(fn field_name ->
      Enum.map([:camelize, :dasherize, :underscore], fn field_case ->
        quote do
          def recase_field(_resource, unquote(field_name), unquote(field_case)),
            do: unquote(JSONAPIPlug.recase(field_name, field_case))
        end
      end)
    end)
  end

  def id_attribute(_resource), do: :id
  def attributes(_resource), do: []
  def field_name(_resource, field_name), do: field_name
  def field_option(_resource, _field_name, _option), do: nil
  def path(_resource), do: nil
  def recase_field(_resource, field, _case), do: field
  def relationships(_resource), do: []
  def type(_resource), do: ""
end
