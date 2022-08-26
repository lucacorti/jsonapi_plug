defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias JSONAPIPlug.{API, Document, View}

  @type case :: :camelize | :dasherize | :underscore

  @type t :: %__MODULE__{
          api: API.t(),
          document: Document.t() | nil,
          fields: term(),
          filter: term(),
          include: term(),
          page: term(),
          sort: term(),
          view: View.t()
        }
  defstruct api: nil,
            document: nil,
            fields: nil,
            filter: nil,
            include: nil,
            page: nil,
            sort: nil,
            view: nil

  @doc """
  JSON:API MIME type

  Returns the JSON:API MIME type.
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"

  @doc """
  Recase resource fields

  Changes the case of resource field names to the specified case, leaving ignoring underscores
  or dashes that are not between letters/numbers

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
  @spec recase(View.field_name() | String.t(), case()) :: String.t()
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
