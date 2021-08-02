defmodule JSONAPI.Document do
  @moduledoc """
  JSONAPI Document
  """
  alias JSONAPI.Document.{Error, Resource}
  alias JSONAPI.View
  alias Plug.Conn

  @type meta ::
          String.t() | integer() | float() | [meta()] | %{String.t() => meta()}

  @type links :: %{String.t() => String.t()}

  @type t :: %__MODULE__{
          data: Resource.t() | [Resource.t()] | nil,
          errors: [Error.t()] | nil,
          included: [Resource.t()] | nil,
          links: links() | nil,
          meta: meta() | nil
        }

  defstruct data: nil, errors: nil, included: nil, links: nil, meta: nil

  @doc """
  Takes a view, resource and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have resource structs.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.QueryParser`.
  """
  @spec serialize(
          View.t(),
          JSONAPI.Resource.t() | [JSONAPI.Resource.t()] | nil,
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

  def serialize(view, resource, %Conn{assigns: %{jsonapi_query: config}} = conn, meta, options) do
    {to_include, serialized_data} =
      Resource.serialize(view, resource, conn, config.include, options)

    %__MODULE__{data: serialized_data}
    |> add_included(to_include)
    |> add_meta(meta)
    |> add_links(resource, view, conn, config.page, options)
  end

  def serialize(view, resource, conn, meta, options) do
    {to_include, serialized_data} = Resource.serialize(view, resource, conn, [], options)

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

  defimpl Jason.Encoder do
    alias JSONAPI.Document

    def encode(%Document{included: []} = document, options) do
      encode(%Document{document | included: nil}, options)
    end

    def encode(document, options) do
      document
      |> Map.from_struct()
      |> Enum.reject(fn
        {_key, nil} -> true
        {_key, []} -> true
        _ -> false
      end)
      |> Enum.into(%{})
      |> Jason.Encode.map(options)
    end
  end
end
