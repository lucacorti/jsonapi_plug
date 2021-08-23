defmodule JSONAPI.Field do
  @moduledoc """
  JSON:API Field related functions

  https://jsonapi.org/format/#document-resource-object-fields
  """

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

  def camelize(value) when value == "", do: value

  def camelize(value) when is_binary(value) do
    with words <-
           Regex.split(
             ~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])},
             to_string(value)
           ) do
      [h | t] = words |> Enum.filter(&(&1 != ""))

      Enum.join([String.downcase(h) | camelize_list(t)])
    end
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

  def dasherize(value) when is_binary(value) do
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
  iex> expand(%{"foo-bar" => "baz"}, &underscore/1)
  %{"foo_bar" => "baz"}

  iex> expand(%{"foo_bar" => "baz"}, &dasherize/1)
  %{"foo-bar" => "baz"}

  iex> expand(%{"foo-bar" => "baz"}, &camelize/1)
  %{"fooBar" => "baz"}

  iex> expand({"foo-bar", "dollar-sol"}, &underscore/1)
  {"foo_bar", "dollar-sol"}

  iex> expand({"foo-bar", %{"a-d" => "z-8"}}, &underscore/1)
  {"foo_bar", %{"a_d" => "z-8"}}

  iex> expand(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"}, &underscore/1)
  %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

  iex> expand(%{"f-b" => %{"a-d" => %{"z-w" => "z"}}, "c-d" => "e"}, &underscore/1)
  %{"f_b" => %{"a_d" => %{"z_w" => "z"}}, "c_d" => "e"}

  iex> expand(:"foo-bar", &underscore/1)
  "foo_bar"

  iex> expand(:foo_bar, &dasherize/1)
  "foo-bar"

  iex> expand(:"foo-bar", &camelize/1)
  "fooBar"

  iex> expand(%{"f-b" => "a-d"}, &underscore/1)
  %{"f_b" => "a-d"}

  iex> expand(%{"inserted-at" => ~N[2019-01-17 03:27:24.776957]}, &underscore/1)
  %{"inserted_at" => ~N[2019-01-17 03:27:24.776957]}

  iex> expand(%{"xValue" => 123}, &underscore/1)
  %{"x_value" => 123}

  iex> expand(%{"attributes" => %{"corgiName" => "Wardel"}}, &underscore/1)
  %{"attributes" => %{"corgi_name" => "Wardel"}}

  iex> expand(%{"attributes" => %{"corgiName" => ["Wardel"]}}, &underscore/1)
  %{"attributes" => %{"corgi_name" => ["Wardel"]}}

  iex> expand(%{"attributes" => %{"someField" => ["SomeValue", %{"nestedField" => "Value"}]}}, &underscore/1)
  %{"attributes" => %{"some_field" => ["SomeValue", %{"nested_field" => "Value"}]}}

  iex> expand([%{"fooBar" => "a"}, %{"fooBar" => "b"}], &underscore/1)
  [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

  iex> expand([%{"foo_bar" => "a"}, %{"foo_bar" => "b"}], &camelize/1)
  [%{"fooBar" => "a"}, %{"fooBar" => "b"}]

  iex> expand(%{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}, &underscore/1)
  %{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}

  iex> expand(%{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}, &camelize/1)
  %{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}

  iex> expand(%{"foo_attributes" => [%{"foo_bar" => [1, 2]}]}, &camelize/1)
  %{"fooAttributes" => [%{"fooBar" => [1, 2]}]}
  """
  @spec expand(String.t() | atom() | tuple() | map() | list(), function()) :: tuple()
  def expand(%{__struct__: _} = value, _fun), do: value

  def expand(map, fun) when is_map(map) do
    Enum.into(map, %{}, &expand(&1, fun))
  end

  def expand(values, fun) when is_list(values) do
    Enum.map(values, &expand(&1, fun))
  end

  def expand({key, value}, fun) when is_map(value) do
    {fun.(key), expand(value, fun)}
  end

  def expand({key, values}, fun) when is_list(values) do
    {
      fun.(key),
      Enum.map(values, fn
        string when is_binary(string) -> string
        value -> expand(value, fun)
      end)
    }
  end

  def expand({key, value}, fun) do
    {fun.(key), value}
  end

  def expand(value, fun) when is_binary(value) or is_atom(value) do
    fun.(value)
  end

  def expand(value, _fun) do
    value
  end

  def transform(fields) do
    case Application.get_env(:jsonapi, :field_transformation) do
      :camelize -> expand(fields, &camelize/1)
      :dasherize -> expand(fields, &dasherize/1)
      _ -> fields
    end
  end
end
