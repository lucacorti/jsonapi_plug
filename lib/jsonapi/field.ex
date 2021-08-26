defmodule JSONAPI.Field do
  @moduledoc """
  JSON:API Field related functions

  https://jsonapi.org/format/#document-resource-object-fields
  """

  defmodule NotLoaded do
    @moduledoc """
    Placeholder for missing JSON:API fields
    """

    alias JSONAPI.Resource

    @type t :: %__MODULE__{
            field: Resource.field(),
            id: Resource.id() | nil,
            type: Resource.type() | nil
          }
    @enforce_keys [:field]
    defstruct [:field, :id, :type]
  end

  @doc """
  Replace underscores or dashes between words in `value` with camelCasing

  Ignores underscores or dashes that are not between letters/numbers

  ## Examples

      iex> camelize("top_posts")
      "topPosts"

      iex> camelize(:top_posts)
      "topPosts"

      iex> camelize("_top_posts")
      "_topPosts"

      iex> camelize("_top__posts_")
      "_top__posts_"

      iex> camelize("")
      ""

  """
  @spec camelize(atom() | String.t()) :: String.t()
  def camelize(value) when is_atom(value) do
    value
    |> to_string()
    |> camelize()
  end

  def camelize(""), do: ""

  def camelize(value) do
    [h | t] =
      Regex.split(~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])}, to_string(value))
      |> Enum.filter(&(&1 != ""))

    Enum.join([String.downcase(h) | camelize_list(t)])
  end

  defp camelize_list([]), do: []
  defp camelize_list([h | t]), do: [String.capitalize(h) | camelize_list(t)]

  @doc """
  Replace underscores between words in `value` with dashes

  Ignores underscores that are not between letters/numbers

  ## Examples

      iex> dasherize("top_posts")
      "top-posts"

      iex> dasherize("_top_posts")
      "_top-posts"

      iex> dasherize("_top__posts_")
      "_top__posts_"

  """
  @spec dasherize(atom() | String.t()) :: String.t()
  def dasherize(value) when is_atom(value) do
    value
    |> to_string()
    |> dasherize()
  end

  def dasherize(value) do
    String.replace(value, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers

  ## Examples

      iex> underscore("top-posts")
      "top_posts"

      iex> underscore(:top_posts)
      "top_posts"

      iex> underscore("-top-posts")
      "-top_posts"

      iex> underscore("-top--posts-")
      "-top--posts-"

      iex> underscore("corgiAge")
      "corgi_age"

  """
  @spec underscore(atom() | String.t()) :: String.t()
  def underscore(value) when is_atom(value) do
    value
    |> to_string()
    |> underscore()
  end

  def underscore(value) do
    value
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end
end
