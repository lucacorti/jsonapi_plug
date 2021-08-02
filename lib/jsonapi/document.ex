defmodule JSONAPI.Document do
  @moduledoc """
  JSON:API Document

  See https://jsonapi.org/format/#document-structure
  """

  alias JSONAPI.{
    Config,
    Document.ErrorObject,
    Document.LinksObject,
    Document.ResourceObject,
    Resource,
    View
  }

  alias Plug.Conn

  @type meta :: String.t() | integer() | float() | [meta()] | %{String.t() => meta()} | nil
  @type links :: LinksObject.t() | nil

  @type t :: %__MODULE__{
          data: ResourceObject.t() | [ResourceObject.t()] | nil,
          errors: [ErrorObject.t()] | nil,
          included: [ResourceObject.t()] | nil,
          links: links(),
          meta: meta()
        }
  defstruct [:data, :errors, :included, :links, :meta]

  @doc """
  Takes a view, resource and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have resource structs.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.QueryParser`.
  """
  @spec serialize(
          View.t(),
          Resource.t() | [Resource.t()] | nil,
          Conn.t() | nil,
          meta() | nil,
          View.options()
        ) :: t()
  def serialize(view, resource, conn \\ nil, meta \\ nil, options \\ [])

  def serialize(view, nil = resource, conn, meta, options) do
    %__MODULE__{}
    |> add_meta(meta)
    |> add_links(resource, view, conn, nil, options)
  end

  def serialize(
        view,
        resource,
        %Conn{assigns: %{jsonapi_query: %Config{} = config}} = conn,
        meta,
        options
      ) do
    {to_include, serialized_data} =
      ResourceObject.serialize(view, resource, conn, config.include || [], options)

    %__MODULE__{data: serialized_data}
    |> add_included(to_include)
    |> add_meta(meta)
    |> add_links(resource, view, conn, config.page || %{}, options)
  end

  def serialize(view, resource, conn, meta, options) do
    {to_include, serialized_data} = ResourceObject.serialize(view, resource, conn, [], options)

    %__MODULE__{data: serialized_data}
    |> add_included(to_include)
    |> add_meta(meta)
    |> add_links(resource, view, conn, nil, options)
  end

  defp add_included(document, [] = _to_include), do: document

  defp add_included(%__MODULE__{} = document, to_include) do
    included =
      to_include
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    %__MODULE__{document | included: included}
  end

  defp add_links(%__MODULE__{} = document, resources, view, conn, page, options)
       when is_list(resources) do
    links =
      resources
      |> view.links(conn)
      |> Map.merge(view.pagination_links(resources, conn, page, options))
      |> Map.merge(%{self: View.url_for_pagination(view, resources, conn, page)})

    %__MODULE__{document | links: links}
  end

  defp add_links(%__MODULE__{} = document, resource, view, conn, _page, _options) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: view.url_for(resource, conn)})

    %__MODULE__{document | links: links}
  end

  defp add_meta(%__MODULE__{} = document, meta) when is_map(meta),
    do: %__MODULE__{document | meta: meta}

  defp add_meta(document, _meta), do: document
end

defimpl Jason.Encoder,
  for: [
    JSONAPI.Document,
    JSONAPI.Document.ErrorObject,
    JSONAPI.Document.LinksObject,
    JSONAPI.Document.ResourceObject,
    JSONAPI.Document.RelationshipObject
  ] do
  def encode(document, options) do
    document
    |> Map.from_struct()
    |> Enum.reject(fn
      {_key, nil} -> true
      {_key, []} -> true
      # {_key, %{} = map} when map_size(map) == 0 -> true
      _ -> false
    end)
    |> Enum.into(%{})
    |> Jason.Encode.map(options)
  end
end
