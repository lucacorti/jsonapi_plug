defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias Plug.Conn
  alias JSONAPIPlug.{API, Document, View}

  @type case :: :camelize | :dasherize | :underscore

  @type t :: %__MODULE__{
          api: API.t(),
          document: Document.t() | nil,
          fields: term(),
          filter: term(),
          include: term(),
          params: Conn.params(),
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
            params: nil,
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

  Changes the case of resource field names to the specified case.

  ## Examples

      iex> recase("top_posts", :camelize)
      "topPosts"

      iex> recase(:top_posts, :camelize)
      "topPosts"

      iex> recase("_top_posts", :camelize)
      "topPosts"

      iex> recase("_top__posts_", :camelize)
      "topPosts"

      iex> recase("top_posts", :dasherize)
      "top-posts"

      iex> recase("_top_posts", :dasherize)
      "top-posts"

      iex> recase("_top__posts_", :dasherize)
      "top-posts"

      iex> recase("top-posts", :underscore)
      "top_posts"

      iex> recase(:top_posts, :underscore)
      "top_posts"

      iex> recase("-top-posts", :underscore)
      "top_posts"

      iex> recase("-top--posts-", :underscore)
      "top_posts"

      iex> recase("corgiAge", :underscore)
      "corgi_age"
  """
  @spec recase(View.field_name() | String.t(), case()) :: String.t()
  def recase(field, to_case) when is_atom(field) do
    field
    |> to_string()
    |> recase(to_case)
  end

  def recase(field, :camelize), do: Recase.to_camel(field)
  def recase(field, :dasherize), do: Recase.to_kebab(field)
  def recase(field, :underscore), do: Recase.underscore(field)
end
