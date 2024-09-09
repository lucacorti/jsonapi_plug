defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias JSONAPIPlug.{API, Document, Normalizer, Resource}
  alias JSONAPIPlug.Document.ResourceObject
  alias Plug.Conn

  @typedoc "String case"
  @type case :: :camelize | :dasherize | :underscore

  @typedoc "JSONAPIPlug context"
  @type t :: %__MODULE__{
          allowed_includes: keyword(keyword()),
          api: API.t(),
          case: case(),
          base_url: String.t(),
          fields: term(),
          filter: term(),
          include: term(),
          normalizer: Normalizer.t(),
          page: term(),
          params: Conn.params(),
          resource: Resource.t(),
          sort: term()
        }
  defstruct allowed_includes: nil,
            api: nil,
            base_url: nil,
            case: nil,
            fields: nil,
            filter: nil,
            include: nil,
            normalizer: nil,
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

  @doc """
  Render JSON:API response

  Renders the JSON:API response for the specified Resource.
  """
  @spec render(
          Conn.t(),
          Resource.t() | [Resource.t()] | nil,
          Document.meta() | nil,
          Resource.options()
        ) ::
          Document.t() | no_return()
  def render(
        conn,
        resource_or_resources \\ nil,
        meta \\ nil,
        options \\ []
      ) do
    Normalizer.normalize(conn, resource_or_resources, meta, options)
    |> Document.serialize()
  end

  @doc """
  Generate relationships link

  Generates the relationships link for a resource.
  """
  @spec url_for_relationship(
          Resource.t() | [Resource.t()],
          Conn.t() | nil,
          ResourceObject.type()
        ) ::
          String.t()
  def url_for_relationship(resource_or_resources, conn, relationship_type) do
    Enum.join([url_for(resource_or_resources, conn), "relationships", relationship_type], "/")
  end

  @doc """
  Generates the resource link

  Generates the resource link for a resource.
  """
  @spec url_for(Resource.t() | [Resource.t()] | nil, Conn.t() | nil) :: String.t()
  def url_for(
        resources,
        %Conn{private: %{jsonapi_plug: %__MODULE__{} = jsonapi_plug}}
      )
      when is_nil(resources) or is_list(resources),
      do: jsonapi_plug.base_url

  def url_for(
        resource,
        %Conn{private: %{jsonapi_plug: %__MODULE__{} = jsonapi_plug}}
      ) do
    Enum.join(
      [
        jsonapi_plug.base_url,
        Map.get(resource, Resource.id_attribute(resource)) |> to_string()
      ],
      "/"
    )
  end

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
    field
    |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end
end
