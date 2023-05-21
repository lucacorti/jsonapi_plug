defmodule JSONAPIPlug.Resource do
  @moduledoc """
  A Resource is simply a module that describes how to render your data as JSON:API resources.

  You can implement a resource by "use-ing" the `JSONAPIPlug.Resource` module:

      defmodule MyApp.UsersResource do
        use JSONAPIPlug.Resource,
          type: "user",
          attributes: [:name, :surname, :username]
      end

  See `t:options/0` for all available options you can pass to `use JSONAPIPlug.Resource`.

  You can now call `UsersResource.render("show.json", %{data: user})` or `Resource.render(UsersResource, conn, user)`
  to render a valid JSON:API document from your data. If you use phoenix, you can use:

      render(conn, "show.json", %{data: user})

  in your controller functions to render the document in the same way.

  ## Attributes

  By default, the resulting JSON document consists of resources taken from your data.
  Only resource  attributes defined on the resource will be (de)serialized. You can customize
  how attributes are handled by passing a keyword list of options:

      defmodule MyApp.UsersResource do
        use JSONAPIPlug.Resource,
          type: "user",
          attributes: [
            username: nil,
            fullname: [deserialize: false, serialize: &fullname/2]
          ]

        defp fullname(resource, conn), do: "\#{resouce.first_name} \#{resource.last_name}"
      end

  In this example we are defining a computed attribute by passing the `serialize` option a function reference.
  Serialization functions take `resource` and `conn` as arguments and return the attribute value to be serialized.
  The `deserialize` option set to `false` makes sure the attribute is not deserialized when receiving a request.

  ## Relationships

  Relationships are defined by passing the `relationships` option to `use JSONAPIPlug.Resource`.

      defmodule MyApp.PostResource do
        use JSONAPIPlug.Resource,
          type: "post",
          attributes: [:text, :body]
          relationships: [
            author: [resource: MyApp.UsersResource],
            comments: [many: true, resource: MyApp.CommentsResource]
          ]
      end

      defmodule MyApp.CommentsResource do
        alias MyApp.UsersResource

        use JSONAPIPlug.Resource,
          type: "comment",
          attributes: [:text]
          relationships: [post: [resource: MyApp.PostResource]]
      end

  When requesting `GET /posts?include=author`, if the author key is present on the data you pass from the
  controller it will appear in the `included` section of the JSON:API response.

  ## Links

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. If you need to use different values for some reason, you can override them
  using `JSONAPIPlug.API` configuration options in your api configuration:

      config :my_app, MyApp.API, host: "adifferenthost.com"
  """

  @attribute_schema [
    name: [
      doc: "Maps the resource attribute name to the given key.",
      type: :atom
    ],
    serialize: [
      doc:
        "Controls attribute serialization. Can be either a boolean (do/don't serialize) or a function reference returning the attribute value to be serialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
      default: true
    ],
    deserialize: [
      doc:
        "Controls attribute deserialization. Can be either a boolean (do/don't deserialize) or a function reference returning the attribute value to be deserialized for full control.",
      type: {:or, [:boolean, {:fun, 2}]},
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
              doc: "A custom path to be used for the resource. Defaults to the resource type.",
              type: :string
            ],
            relationships: [
              doc:
                "Resource relationships. This will be used to (de)serialize requests/responses",
              type: :keyword_list,
              keys: [*: [type: :non_empty_keyword_list, keys: @relationship_schema]],
              default: []
            ],
            resource: [
              doc: "Resource",
              type: :atom,
              required: true
            ],
            type: [
              doc: "Resource type. To be used as the JSON:API resource type value",
              type: :string,
              required: true
            ]
          )

  alias JSONAPIPlug.{Document, Normalizer}
  alias Plug.Conn

  defmacro __using__(options) do
    options =
      options
      |> Macro.prewalk(&Macro.expand(&1, __CALLER__))
      |> NimbleOptions.validate!(@schema)

    id_attribute = Keyword.get(options, :id_attribute)
    attributes = Keyword.get(options, :attributes)
    relationships = Keyword.get(options, :relationships)
    type = Keyword.get(options, :type)
    resource = Keyword.get(options, :resource)

    if field =
         Stream.concat(attributes, relationships)
         |> Enum.find(&(field_name(&1) in [:id, :type])) do
      name = field_name(field)

      raise "Illegal field name '#{name}' for resource '#{resource}'. See https://jsonapi.org/format/#document-resource-object-fields for more information."
    end

    quote do
      defimpl JSONAPIPlug.Resource.Attributes, for: unquote(resource) do
        def attributes(_t), do: unquote(attributes)
        def relationships(_t), do: unquote(relationships)
      end

      defimpl JSONAPIPlug.Resource.Identity, for: unquote(resource) do
        def id_attribute(_t), do: unquote(id_attribute)
        def type(_t), do: unquote(type)
      end

      defimpl JSONAPIPlug.Resource.Relationships, for: unquote(resource) do
        def attributes(_t), do: unquote(attributes)
        def relationships(_t), do: unquote(relationships)
      end
    end
  end

  @typedoc "Resource"
  @type t :: struct()

  @type case :: :camelize | :dasherize | :underscore

  @typedoc """
  Resource field name

  The name of a Resource field (attribute or relationship)
  """
  @type field_name :: atom()

  @typedoc """
  Attribute options\n#{NimbleOptions.docs(NimbleOptions.new!(@attribute_schema))}
  """
  @type attribute_options :: [
          name: field_name(),
          serialize: boolean() | (t(), Conn.t() -> term()),
          deserialize: boolean() | (t(), Conn.t() -> term())
        ]

  @typedoc """
  Resource attributes

  A keyword list composed of attribute names and their options
  """
  @type attributes :: [field_name()] | [{field_name(), attribute_options()}]

  @typedoc """
  Relationship options\n#{NimbleOptions.docs(NimbleOptions.new!(@relationship_schema))}
  """
  @type relationship_options :: [many: boolean(), name: field_name(), resource: t()]

  @typedoc """
  Resource attributes

  A keyword list composed of relationship names and their options
  """
  @type relationships :: [{field_name(), relationship_options()}]

  @typedoc """
  Resource field
  """
  @type field ::
          field_name() | {field_name(), attribute_options() | relationship_options()}

  @typedoc """
  Resource type
  """
  @type type :: String.t()

  @doc """
  Field option

  Returns the name of the attribute or relationship for the field definition.
  """
  @spec field_name(field()) :: field_name()
  def field_name(field) when is_atom(field), do: field
  def field_name({name, nil}), do: name
  def field_name({name, options}) when is_list(options), do: name

  def field_name(field) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @doc """
  Field option

  Returns the value of the attribute or relationship option for the field definition.
  """
  @spec field_option(field(), atom()) :: term()
  def field_option(name, _option) when is_atom(name), do: nil
  def field_option({_name, nil}, _option), do: nil

  def field_option({_name, options}, option) when is_list(options),
    do: Keyword.get(options, option)

  def field_option(field, _option, _default) do
    raise "invalid field definition: #{inspect(field)}"
  end

  @doc """
  Recase resource fields

  Changes the case of resource field names to the specified case, ignoring underscores
  or dashes that are not between letters/numbers.

  ## Examples

  iex> field_recase("top_posts", :camelize)
  "topPosts"

  iex> field_recase(:top_posts, :camelize)
  "topPosts"

  iex> field_recase("_top_posts", :camelize)
  "_topPosts"

  iex> field_recase("_top__posts_", :camelize)
  "_top__posts_"

  iex> field_recase("", :camelize)
  ""

  iex> field_recase("top_posts", :dasherize)
  "top-posts"

  iex> field_recase("_top_posts", :dasherize)
  "_top-posts"

  iex> field_recase("_top__posts_", :dasherize)
  "_top__posts_"

  iex> field_recase("top-posts", :underscore)
  "top_posts"

  iex> field_recase(:top_posts, :underscore)
  "top_posts"

  iex> field_recase("-top-posts", :underscore)
  "-top_posts"

  iex> field_recase("-top--posts-", :underscore)
  "-top--posts-"

  iex> field_recase("corgiAge", :underscore)
  "corgi_age"
  """
  @spec field_recase(field_name() | String.t(), case()) :: String.t()
  def field_recase(field, case) when is_atom(field) do
    field
    |> to_string()
    |> field_recase(case)
  end

  def field_recase("", :camelize), do: ""

  def field_recase(field, :camelize) do
    [h | t] =
      Regex.split(~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])}, field)
      |> Enum.filter(&(&1 != ""))

    Enum.join([String.downcase(h) | camelize_list(t)])
  end

  def field_recase(field, :dasherize) do
    String.replace(field, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def field_recase(field, :underscore) do
    field
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp camelize_list([]), do: []
  defp camelize_list([h | t]), do: [String.capitalize(h) | camelize_list(t)]

  @doc """
  Render JSON:API response

  Renders the JSON:API response for the specified resources.
  """
  @spec render(Conn.t(), Resource.t() | [Resource.t()], Document.links(), Document.meta()) ::
          Document.t() | no_return()
  def render(conn, data, links \\ %{}, meta \\ %{}),
    do: Normalizer.normalize(conn, data, links, meta)
end
