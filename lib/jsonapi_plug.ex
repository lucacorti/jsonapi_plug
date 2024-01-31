defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias Plug.Conn
  alias JSONAPIPlug.{API, Resource}

  @type case :: :camelize | :dasherize | :underscore

  @type t :: %__MODULE__{
          allowed_includes: keyword(keyword()),
          api: API.t(),
          fields: term(),
          filter: term(),
          include: term(),
          page: term(),
          params: Conn.params(),
          resource: Resource.t(),
          sort: term()
        }
  defstruct allowed_includes: nil,
            api: nil,
            fields: nil,
            filter: nil,
            include: nil,
            page: nil,
            params: nil,
            resource: nil,
            sort: nil

  @doc """
  JSON:API MIME type

  Returns the JSON:API MIME type.
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"

  defguardp is_uppercase(a) when ?A <= a and a <= ?Z
  defguardp is_lowercase(a) when ?a <= a and a <= ?z
  defguardp is_letter(a) when is_lowercase(a) or is_uppercase(a)

  @doc """
  Recase resource fields

  Changes the case of resource field names to the specified case, ignoring underscores
  or dashes that are not between letters/numbers.

  ## Examples

      iex> recase("top_posts", :camelize)
      "topPosts"

      iex> recase(:top_posts, :camelize)
      "topPosts"

      iex> recase("_top_posts", :camelize)
      "_topPosts"

      iex> recase("_top__posts_", :camelize)
      "_top__posts_"

      iex> recase("", :camelize)
      ""

      iex> recase("top_posts", :dasherize)
      "top-posts"

      iex> recase("_top_posts", :dasherize)
      "_top-posts"

      iex> recase("_top__posts_", :dasherize)
      "_top__posts_"

      iex> recase("top-posts", :underscore)
      "top_posts"

      iex> recase(:top_posts, :underscore)
      "top_posts"

      iex> recase("-top-posts", :underscore)
      "-top_posts"

      iex> recase("-top--posts-", :underscore)
      "-top--posts-"

      iex> recase("corgiAge", :underscore)
      "corgi_age"
  """
  @spec recase(Resource.field_name() | String.t(), case()) :: String.t()
  def recase(field, case) when is_atom(field) do
    field
    |> to_string()
    |> recase(case)
  end

  def recase("", :camelize), do: ""

  def recase(field, :camelize) do
    [h | t] =
      Regex.split(~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])}, field)
      |> Enum.filter(&(&1 != ""))

    Enum.join([String.downcase(h) | Enum.map(t, &String.capitalize/1)])
  end

  def recase(field, :dasherize) do
    String.replace(field, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def recase(field, :underscore) do
    recase_underscore(field, "")
  end

  def recase_underscore(<<?-, field::binary>>, acc),
    do: recase_underscore(field, acc <> <<?->>)

  def recase_underscore(<<a::utf8, b::utf8, field::binary>>, acc)
      when is_lowercase(a) and is_uppercase(b) do
    recase_underscore(field, acc <> downcase(<<a>>) <> "_" <> downcase(<<b>>))
  end

  def recase_underscore(<<a::utf8, ?-, b::utf8, field::binary>>, acc)
      when is_letter(a) and is_letter(b) do
    recase_underscore(field, acc <> downcase(<<a>>) <> "_" <> downcase(<<b>>))
  end

  def recase_underscore(<<a::utf8, field::binary>>, acc) do
    recase_underscore(field, acc <> downcase(<<a>>))
  end

  def recase_underscore("", acc), do: acc

  defp downcase(<<a>>) when is_uppercase(a), do: <<a + 32>>
  defp downcase(rest), do: rest
end
