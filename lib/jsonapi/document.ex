defmodule JSONAPI.Document do
  @moduledoc """
  JSON:API Document

  Handles serialization, deserialization and validation of JSON:API Documents.

  https://jsonapi.org/format/#document-structure
  """

  alias JSONAPI.{
    API,
    Document.ErrorObject,
    Document.JSONAPIObject,
    Document.LinksObject,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Pagination,
    View
  }

  alias Plug.Conn

  @type payload :: %{String.t() => value()}
  @type value :: String.t() | integer() | float() | [value()] | %{String.t() => value()} | nil

  @typedoc """
  Primary Data

  https://jsonapi.org/format/#document-top-level
  """
  @type data :: ResourceObject.t() | [ResourceObject.t()]

  @typedoc """
  Errors

  https://jsonapi.org/format/#errors
  """
  @type errors :: [ErrorObject.t()]

  @typedoc """
  Included Resources

  https://jsonapi.org/format/#document-compound-documents
  """
  @type included :: [ResourceObject.t()]

  @typedoc """
  JSONAPI Object

  https://jsonapi.org/format/#document-jsonapi-object
  """
  @type jsonapi :: JSONAPIObject.t()

  @typedoc """
  Meta Information

  https://jsonapi.org/format/#document-meta
  """
  @type meta :: %{atom() => value()}

  @typedoc """
  Links

  https://jsonapi.org/format/#document-links
  """
  @type links :: %{atom() => LinksObject.link()}

  @type t :: %__MODULE__{
          data: data() | View.data() | nil,
          errors: errors() | nil,
          included: included() | nil,
          jsonapi: jsonapi() | nil,
          links: links() | nil,
          meta: meta() | nil
        }
  defstruct [:data, :errors, :included, :jsonapi, :links, :meta]

  @doc """
  Takes a view, resource and a optional plug connection and returns a JSON:API document.
  This assumes you are using `JSONAPI.View` and pass structs implementing `JSONAPI.Resource`.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.Plug.Request`.
  """
  @spec serialize(
          t(),
          View.t(),
          Conn.t() | nil,
          View.options()
        ) :: t()
  def serialize(document, view, conn \\ nil, options \\ []) do
    document
    |> serialize_jsonapi(view, conn, options)
    |> serialize_links(view, conn, options)
    |> serialize_data(view, conn, options)
  end

  defp serialize_data(%__MODULE__{data: nil} = document, _view, _conn, _options),
    do: document

  defp serialize_data(%__MODULE__{data: resources} = document, view, conn, options)
       when is_list(resources) do
    {included, data} =
      Enum.flat_map_reduce(resources, [], fn resource, resource_objects ->
        {included, resource_object} = ResourceObject.serialize(view, resource, conn, options)
        {included, [resource_object | resource_objects]}
      end)

    %__MODULE__{document | data: data, included: included |> List.flatten() |> Enum.uniq()}
  end

  defp serialize_data(%__MODULE__{data: resource} = document, view, conn, options) do
    {included, data} = ResourceObject.serialize(view, resource, conn, options)

    %__MODULE__{document | data: data, included: included |> List.flatten() |> Enum.uniq()}
  end

  defp serialize_jsonapi(
         %__MODULE__{} = document,
         _view,
         %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}},
         _options
       ),
       do: %__MODULE__{
         document
         | jsonapi: %JSONAPIObject{version: API.get_config(jsonapi.api, :version, :"1.0")}
       }

  defp serialize_jsonapi(
         %__MODULE__{} = document,
         _view,
         _conn,
         _options
       ),
       do: %__MODULE__{document | jsonapi: %JSONAPIObject{version: :"1.0"}}

  defp serialize_links(
         %__MODULE__{data: resources} = document,
         view,
         %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn,
         options
       )
       when is_list(resources) do
    links =
      resources
      |> view.links(conn)
      |> Map.merge(pagination_links(view, resources, conn, jsonapi.page, options))
      |> Map.merge(%{self: Pagination.url_for(view, resources, conn, jsonapi.page)})

    %__MODULE__{document | links: links}
  end

  defp serialize_links(%__MODULE__{data: resource} = document, view, conn, _options) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: View.url_for(view, resource, conn)})

    %__MODULE__{document | links: links}
  end

  defp pagination_links(
         view,
         resources,
         %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn,
         page,
         options
       ) do
    pagination = API.get_config(jsonapi.api, :pagination)

    if pagination do
      pagination.paginate(view, resources, conn, page, options)
    else
      %{}
    end
  end

  defp pagination_links(_view, _resources, _conn, _page, _options), do: %{}

  @spec deserialize(View.t(), Conn.t()) :: t()
  def deserialize(view, %Conn{body_params: %Conn.Unfetched{aspect: :body_params}}) do
    raise "Body unfetched when trying to deserialize request for #{view}"
  end

  def deserialize(view, %Conn{body_params: payload}) do
    %__MODULE__{}
    |> deserialize_data(view, payload)
    |> deserialize_meta(view, payload)
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data, "included" => included})
       when is_list(data) and is_list(included) do
    %__MODULE__{
      document
      | data: Enum.map(data, &ResourceObject.deserialize(view, &1, included))
    }
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data, "included" => included})
       when is_map(data) and is_list(included) do
    %__MODULE__{document | data: ResourceObject.deserialize(view, data, included)}
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data})
       when is_list(data) do
    %__MODULE__{
      document
      | data: Enum.map(data, &ResourceObject.deserialize(view, &1, []))
    }
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data})
       when is_map(data) do
    %__MODULE__{document | data: ResourceObject.deserialize(view, data, [])}
  end

  defp deserialize_data(%__MODULE__{} = document, _view, _payload),
    do: document

  defp deserialize_meta(%__MODULE__{} = document, _view, %{"meta" => meta})
       when is_map(meta),
       do: %__MODULE__{document | meta: meta}

  defp deserialize_meta(%__MODULE__{} = document, _view, _payload),
    do: document

  defimpl Jason.Encoder,
    for: [
      __MODULE__,
      ErrorObject,
      JSONAPIObject,
      LinksObject,
      ResourceIdentifierObject,
      ResourceObject,
      RelationshipObject
    ] do
    def encode(document, options) do
      document
      |> Map.from_struct()
      |> Enum.reject(fn
        {_key, nil} -> true
        {_key, []} -> true
        {_key, %{} = map} when map_size(map) == 0 -> true
        _ -> false
      end)
      |> Enum.into(%{})
      |> Jason.Encode.map(options)
    end
  end
end
