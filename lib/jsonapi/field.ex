defmodule JSONAPI.Field do
  @moduledoc "JSON:API Field"

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers

  ## Examples

      iex> JSONAPI.Field.underscore("top-posts")
      "top_posts"

      iex> JSONAPI.Field.underscore(:top_posts)
      "top_posts"

      iex> JSONAPI.Field.underscore("-top-posts")
      "-top_posts"

      iex> JSONAPI.Field.underscore("-top--posts-")
      "-top--posts-"

      iex> JSONAPI.Field.underscore("corgiAge")
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

      iex> JSONAPI.Field.dasherize("top_posts")
      "top-posts"

      iex> JSONAPI.Field.dasherize("_top_posts")
      "_top-posts"

      iex> JSONAPI.Field.dasherize("_top__posts_")
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

      iex> JSONAPI.Field.camelize("top_posts")
      "topPosts"

      iex> JSONAPI.Field.camelize(:top_posts)
      "topPosts"

      iex> JSONAPI.Field.camelize("_top_posts")
      "_topPosts"

      iex> JSONAPI.Field.camelize("_top__posts_")
      "_top__posts_"

      iex> JSONAPI.Field.camelize("")
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

  @doc """
  iex> JSONAPI.Field.expand(%{"foo-bar" => "baz"}, &JSONAPI.Field.underscore/1)
  %{"foo_bar" => "baz"}

  iex> JSONAPI.Field.expand(%{"foo_bar" => "baz"}, &JSONAPI.Field.dasherize/1)
  %{"foo-bar" => "baz"}

  iex> JSONAPI.Field.expand(%{"foo-bar" => "baz"}, &JSONAPI.Field.camelize/1)
  %{"fooBar" => "baz"}

  iex> JSONAPI.Field.expand({"foo-bar", "dollar-sol"}, &JSONAPI.Field.underscore/1)
  {"foo_bar", "dollar-sol"}

  iex> JSONAPI.Field.expand({"foo-bar", %{"a-d" => "z-8"}}, &JSONAPI.Field.underscore/1)
  {"foo_bar", %{"a_d" => "z-8"}}

  iex> JSONAPI.Field.expand(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"}, &JSONAPI.Field.underscore/1)
  %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

  iex> JSONAPI.Field.expand(%{"f-b" => %{"a-d" => %{"z-w" => "z"}}, "c-d" => "e"}, &JSONAPI.Field.underscore/1)
  %{"f_b" => %{"a_d" => %{"z_w" => "z"}}, "c_d" => "e"}

  iex> JSONAPI.Field.expand(:"foo-bar", &JSONAPI.Field.underscore/1)
  "foo_bar"

  iex> JSONAPI.Field.expand(:foo_bar, &JSONAPI.Field.dasherize/1)
  "foo-bar"

  iex> JSONAPI.Field.expand(:"foo-bar", &JSONAPI.Field.camelize/1)
  "fooBar"

  iex> JSONAPI.Field.expand(%{"f-b" => "a-d"}, &JSONAPI.Field.underscore/1)
  %{"f_b" => "a-d"}

  iex> JSONAPI.Field.expand(%{"inserted-at" => ~N[2019-01-17 03:27:24.776957]}, &JSONAPI.Field.underscore/1)
  %{"inserted_at" => ~N[2019-01-17 03:27:24.776957]}

  iex> JSONAPI.Field.expand(%{"xValue" => 123}, &JSONAPI.Field.underscore/1)
  %{"x_value" => 123}

  iex> JSONAPI.Field.expand(%{"attributes" => %{"corgiName" => "Wardel"}}, &JSONAPI.Field.underscore/1)
  %{"attributes" => %{"corgi_name" => "Wardel"}}

  iex> JSONAPI.Field.expand(%{"attributes" => %{"corgiName" => ["Wardel"]}}, &JSONAPI.Field.underscore/1)
  %{"attributes" => %{"corgi_name" => ["Wardel"]}}

  iex> JSONAPI.Field.expand(%{"attributes" => %{"someField" => ["SomeValue", %{"nestedField" => "Value"}]}}, &JSONAPI.Field.underscore/1)
  %{"attributes" => %{"some_field" => ["SomeValue", %{"nested_field" => "Value"}]}}

  iex> JSONAPI.Field.expand([%{"fooBar" => "a"}, %{"fooBar" => "b"}], &JSONAPI.Field.underscore/1)
  [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

  iex> JSONAPI.Field.expand([%{"foo_bar" => "a"}, %{"foo_bar" => "b"}], &JSONAPI.Field.camelize/1)
  [%{"fooBar" => "a"}, %{"fooBar" => "b"}]

  iex> JSONAPI.Field.expand(%{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}, &JSONAPI.Field.underscore/1)
  %{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}

  iex> JSONAPI.Field.expand(%{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}, &JSONAPI.Field.camelize/1)
  %{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}

  iex> JSONAPI.Field.expand(%{"foo_attributes" => [%{"foo_bar" => [1, 2]}]}, &JSONAPI.Field.camelize/1)
  %{"fooAttributes" => [%{"fooBar" => [1, 2]}]}
  """
  @spec expand(String.t() | atom() | tuple() | map() | list(), function()) :: tuple
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
      :camelize -> expand(fields, &JSONAPI.Field.camelize/1)
      :dasherize -> expand(fields, &dasherize/1)
      _ -> fields
    end
  end
end
