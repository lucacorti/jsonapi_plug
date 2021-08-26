defmodule JSONAPI.UnderscoreParameters do
  @moduledoc """
  Takes dasherized JSON:API params and deserializes them to underscored params. Add
  this to your API's pipeline to aid in dealing with incoming parameters such as query
  params or data.

  Note that this Plug will only underscore parameters when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Example

  %{
    "data" => %{
      "attributes" => %{
        "foo-bar" => true
      }
    }
  }

  are transformed to:

  %{
    "data" => %{
      "attributes" => %{
        "foo_bar" => true
      }
    }
  }

  Moreover, with a GET request like:

      GET /example?filters[dog-breed]=Corgi

  **Without** this Plug your index action would look like:

      def index(conn, %{"filters" => %{"dog-breed" => "Corgi"}})

  And **with** this Plug:

      def index(conn, %{"filters" => %{"dog_breed" => "Corgi"}})

  Your API's pipeline might look something like this:

      pipeline :api do
        plug JSONAPI.EnsureSpec
        plug JSONAPI.UnderscoreParameters
      end
  """

  alias JSONAPI.Field
  alias Plug.Conn

  @doc false
  def init(opts), do: opts

  @doc false
  def call(%Conn{params: params} = conn, _opts) do
    if JSONAPI.mime_type() in Conn.get_req_header(conn, "content-type") do
      %Conn{conn | params: underscore(params, &Field.underscore/1)}
    else
      conn
    end
  end

  @doc """
  iex> underscore(%{"foo-bar" => "baz"}, &underscore/1)
  %{"foo_bar" => "baz"}

  iex> underscore(%{"foo_bar" => "baz"}, &dasherize/1)
  %{"foo-bar" => "baz"}

  iex> underscore(%{"foo-bar" => "baz"}, &camelize/1)
  %{"fooBar" => "baz"}

  iex> underscore({"foo-bar", "dollar-sol"}, &underscore/1)
  {"foo_bar", "dollar-sol"}

  iex> underscore({"foo-bar", %{"a-d" => "z-8"}}, &underscore/1)
  {"foo_bar", %{"a_d" => "z-8"}}

  iex> underscore(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"}, &underscore/1)
  %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

  iex> underscore(%{"f-b" => %{"a-d" => %{"z-w" => "z"}}, "c-d" => "e"}, &underscore/1)
  %{"f_b" => %{"a_d" => %{"z_w" => "z"}}, "c_d" => "e"}

  iex> underscore(:"foo-bar", &underscore/1)
  "foo_bar"

  iex> underscore(:foo_bar, &dasherize/1)
  "foo-bar"

  iex> underscore(:"foo-bar", &camelize/1)
  "fooBar"

  iex> underscore(%{"f-b" => "a-d"}, &underscore/1)
  %{"f_b" => "a-d"}

  iex> underscore(%{"inserted-at" => ~N[2019-01-17 03:27:24.776957]}, &underscore/1)
  %{"inserted_at" => ~N[2019-01-17 03:27:24.776957]}

  iex> underscore(%{"xValue" => 123}, &underscore/1)
  %{"x_value" => 123}

  iex> underscore(%{"attributes" => %{"corgiName" => "Wardel"}}, &underscore/1)
  %{"attributes" => %{"corgi_name" => "Wardel"}}

  iex> underscore(%{"attributes" => %{"corgiName" => ["Wardel"]}}, &underscore/1)
  %{"attributes" => %{"corgi_name" => ["Wardel"]}}

  iex> underscore(%{"attributes" => %{"someField" => ["SomeValue", %{"nestedField" => "Value"}]}}, &underscore/1)
  %{"attributes" => %{"some_field" => ["SomeValue", %{"nested_field" => "Value"}]}}

  iex> underscore([%{"fooBar" => "a"}, %{"fooBar" => "b"}], &underscore/1)
  [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

  iex> underscore([%{"foo_bar" => "a"}, %{"foo_bar" => "b"}], &camelize/1)
  [%{"fooBar" => "a"}, %{"fooBar" => "b"}]

  iex> underscore(%{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}, &underscore/1)
  %{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}

  iex> underscore(%{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}, &camelize/1)
  %{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}

  iex> underscore(%{"foo_attributes" => [%{"foo_bar" => [1, 2]}]}, &camelize/1)
  %{"fooAttributes" => [%{"fooBar" => [1, 2]}]}
  """
  @spec underscore(String.t() | atom() | tuple() | map() | list(), function()) :: tuple()
  def underscore(%{__struct__: _} = value, _fun), do: value

  def underscore(map, fun) when is_map(map) do
    Enum.into(map, %{}, &underscore(&1, fun))
  end

  def underscore(values, fun) when is_list(values) do
    Enum.map(values, &underscore(&1, fun))
  end

  def underscore({key, value}, fun) when is_map(value) do
    {fun.(key), underscore(value, fun)}
  end

  def underscore({key, values}, fun) when is_list(values) do
    {
      fun.(key),
      Enum.map(values, fn
        string when is_binary(string) -> string
        value -> underscore(value, fun)
      end)
    }
  end

  def underscore({key, value}, fun) do
    {fun.(key), value}
  end

  def underscore(value, fun) when is_binary(value) or is_atom(value) do
    fun.(value)
  end

  def underscore(value, _fun) do
    value
  end
end
