defmodule JSONAPI.Resource do
  @moduledoc """
  JSON:API Resource
  """

  @type t :: struct()
  @type id :: String.t()
  @type case :: :camelize | :dasherize | :underscore
  @type field :: atom()
  @type type :: String.t()

  @doc """
  Inflects Resource fields for serialization

  Replace underscores or dashes between words in `value` with camelCasing
  Ignores underscores or dashes that are not between letters/numbers

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
  @spec recase(field(), case()) :: String.t()
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

    Enum.join([String.downcase(h) | camelize_list(t)])
  end

  def recase(field, :dasherize) do
    String.replace(field, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def recase(field, :underscore) do
    field
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  defp camelize_list([]), do: []
  defp camelize_list([h | t]), do: [String.capitalize(h) | camelize_list(t)]
end
