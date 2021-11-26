defmodule JSONAPI.Resource do
  @moduledoc """
  JSON:API Resource
  """

  @type t :: struct()
  @type id :: String.t()
  @type inflection :: :camelize | :dasherize | :underscore
  @type field :: atom()
  @type type :: String.t()

  defmodule NotLoaded do
    @moduledoc """
    Placeholder for missing JSON:API fields
    """

    alias JSONAPI.Resource

    @type t :: %__MODULE__{
            id: Resource.id() | nil,
            type: Resource.type() | nil
          }
    defstruct [:id, :type]
  end

  @doc """
  Inflects Resource fields for serialization

  Replace underscores or dashes between words in `value` with camelCasing
  Ignores underscores or dashes that are not between letters/numbers

  ## Examples

      iex> inflect("top_posts", :camelize)
      "topPosts"

      iex> inflect(:top_posts, :camelize)
      "topPosts"

      iex> inflect("_top_posts", :camelize)
      "_topPosts"

      iex> inflect("_top__posts_", :camelize)
      "_top__posts_"

      iex> inflect("", :camelize)
      ""

      iex> inflect("top_posts", :dasherize)
      "top-posts"

      iex> inflect("_top_posts", :dasherize)
      "_top-posts"

      iex> inflect("_top__posts_", :dasherize)
      "_top__posts_"

      iex> inflect("top-posts", :underscore)
      "top_posts"

      iex> inflect(:top_posts, :underscore)
      "top_posts"

      iex> inflect("-top-posts", :underscore)
      "-top_posts"

      iex> inflect("-top--posts-", :underscore)
      "-top--posts-"

      iex> inflect("corgiAge", :underscore)
      "corgi_age"
  """
  @spec inflect(field(), inflection()) :: String.t()
  def inflect(field, inflection) when is_atom(field) do
    field
    |> to_string()
    |> inflect(inflection)
  end

  def inflect("", :camelize), do: ""

  def inflect(field, :camelize) do
    [h | t] =
      Regex.split(~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])}, field)
      |> Enum.filter(&(&1 != ""))

    Enum.join([String.downcase(h) | camelize_list(t)])
  end

  def inflect(field, :dasherize) do
    String.replace(field, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def inflect(field, :underscore) do
    field
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp camelize_list([]), do: []
  defp camelize_list([h | t]), do: [String.capitalize(h) | camelize_list(t)]
end
