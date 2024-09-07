defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias JSONAPIPlug.Document.ResourceObject
  alias JSONAPIPlug.{API, Document, Normalizer, Resource}
  alias Plug.Conn

  @typedoc "String case"
  @type case :: :camelize | :dasherize | :underscore

  @typedoc "JSONAPIPlug context"
  @type t :: %__MODULE__{
          allowed_includes: keyword(keyword()),
          api: API.t(),
          fields: term(),
          filter: term(),
          include: term(),
          page: term(),
          params: Conn.params(),
          resource: Resource.t(),
          sort: term()
        }
  defstruct allowed_includes: nil,
            api: nil,
            fields: nil,
            filter: nil,
            include: nil,
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
  Related Resource based on JSON:API type

  Returns the resource used to handle relationships of the requested type by the passed resource.
  """
  @spec for_related_type(Resource.t(), ResourceObject.type()) :: Resource.t() | nil
  def for_related_type(resource, type) do
    Enum.find_value(resource.relationships(), fn {_relationship, options} ->
      relationship_resource = Keyword.fetch!(options, :resource)

      if relationship_resource.type() == type do
        relationship_resource
      else
        nil
      end
    end)
  end

  @doc """
  Render JSON:API response

  Renders the JSON:API response for the specified Resource.
  """
  @spec render(
          Resource.t(),
          Conn.t(),
          Resource.data() | nil,
          Document.meta() | nil,
          Resource.options()
        ) ::
          Document.t() | no_return()
  def render(
        resource,
        conn,
        data \\ nil,
        meta \\ nil,
        options \\ []
      ) do
    resource
    |> Normalizer.normalize(conn, data, meta, options)
    |> Document.serialize()
  end

  @doc """
  Generate relationships link

  Generates the relationships link for a resource.
  """
  @spec url_for_relationship(
          Resource.t(),
          Resource.resource(),
          Conn.t() | nil,
          ResourceObject.type()
        ) ::
          String.t()
  def url_for_relationship(resource, data, conn, relationship_type) do
    Enum.join([url_for(resource, data, conn), "relationships", relationship_type], "/")
  end

  @doc """
  Generates the resource link

  Generates the resource link for a resource.
  """
  @spec url_for(Resource.t(), Resource.data(), Conn.t() | nil) :: String.t()
  def url_for(resource, data, conn) when is_nil(resource) or is_list(data) do
    conn
    |> render_uri([resource.path() || resource.type()])
    |> to_string()
  end

  def url_for(
        resource,
        data,
        %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn
      ) do
    normalizer = resource.normalizer() || API.get_config(jsonapi_plug.api, [:normalizer])

    conn
    |> render_uri([
      resource.path() || resource.type(),
      normalizer.normalize_attribute(data, resource.id_attribute())
    ])
    |> to_string()
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

  defp render_uri(%Conn{} = conn, path) do
    %URI{
      scheme: scheme(conn),
      host: host(conn),
      path: Enum.join([namespace(conn) | path], "/"),
      port: port(conn)
    }
  end

  defp render_uri(_conn, path), do: %URI{path: "/" <> Enum.join(path, "/")}

  defp scheme(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, scheme: scheme}),
    do: to_string(API.get_config(jsonapi_plug.api, [:scheme], scheme))

  defp scheme(_conn), do: nil

  defp host(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, host: host}),
    do: API.get_config(jsonapi_plug.api, [:host], host)

  defp host(_conn), do: nil

  defp namespace(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}}) do
    case API.get_config(jsonapi_plug.api, [:namespace]) do
      nil -> ""
      namespace -> "/" <> namespace
    end
  end

  defp namespace(_conn), do: ""

  defp port(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, port: port} = conn) do
    case API.get_config(jsonapi_plug.api, [:port], port) do
      nil -> nil
      port -> if port == URI.default_port(scheme(conn)), do: nil, else: port
    end
  end

  defp port(_conn), do: nil
end
