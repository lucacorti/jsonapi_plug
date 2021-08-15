defmodule JSONAPI.Utils.String do
  @moduledoc """
  String manipulation helpers.
  """

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
  @spec underscore(String.t()) :: String.t()
  def underscore(value) when is_binary(value) do
    value
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  @spec underscore(atom) :: String.t()
  def underscore(value) when is_atom(value) do
    value
    |> to_string()
    |> underscore()
  end

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
  @spec dasherize(atom) :: String.t()
  def dasherize(value) when is_atom(value) do
    value
    |> to_string()
    |> dasherize()
  end

  @spec dasherize(String.t()) :: String.t()
  def dasherize(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
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
  @spec camelize(atom) :: String.t()
  def camelize(value) when is_atom(value) do
    value
    |> to_string()
    |> camelize()
  end

  @spec camelize(String.t()) :: String.t()
  def camelize(value) when value == "", do: value

  def camelize(value) when is_binary(value) do
    with words <-
           Regex.split(
             ~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])},
             to_string(value)
           ) do
      [h | t] = words |> Enum.filter(&(&1 != ""))

      [String.downcase(h) | camelize_list(t)]
      |> Enum.join()
    end
  end

  defp camelize_list([]), do: []
  defp camelize_list([h | t]), do: [String.capitalize(h) | camelize_list(t)]
end
