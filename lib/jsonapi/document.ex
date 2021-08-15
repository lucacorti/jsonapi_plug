defmodule JSONAPI.Document do
  @moduledoc """
  JSON:API Document

  Handles serialization, deserialization and validation of JSON:API Documents.

  https://jsonapi.org/format/#document-structure
  """

  alias JSONAPI.{
    Config,
    Document.ErrorObject,
    Document.JSONAPIObject,
    Document.LinksObject,
    Document.RelationshipObject,
    Document.ResourceObject,
    View
  }

  alias Plug.Conn

  @type payload :: %{String.t() => value()}
  @type value :: String.t() | integer() | float() | [value()] | %{String.t() => meta()} | nil

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
  @type meta :: %{String.t() => value()}

  @typedoc """
  Links

  https://jsonapi.org/format/#document-links
  """
  @type links :: %{atom() => LinksObject.link()}

  @type t :: %__MODULE__{
          data: data() | nil,
          errors: errors() | nil,
          included: included() | nil,
          jsonapi: jsonapi() | nil,
          links: links() | nil,
          meta: meta() | nil
        }
  defstruct [:data, :errors, :included, :jsonapi, :links, :meta]

  @doc """
  Takes a view, resource and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have resource structs.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.QueryParser`.
  """
  @spec serialize(
          View.t(),
          View.data() | nil,
          Conn.t() | nil,
          meta() | nil,
          View.options()
        ) :: t()
  def serialize(view, data, conn \\ nil, meta \\ nil, options \\ []) do
    %__MODULE__{}
    |> serialize_data(view, data, conn, options)
    |> serialize_jsonapi(view, data, conn, options)
    |> serialize_meta(view, data, conn, options, meta)
    |> serialize_links(view, data, conn, options)
  end

  defp serialize_data(%__MODULE__{} = document, _view, nil = _resource, _conn, _options),
    do: document

  defp serialize_data(%__MODULE__{} = document, view, resources, conn, options)
       when is_list(resources) do
    {to_include, data} =
      Enum.map_reduce(resources, [], fn resource, resource_objects ->
        {to_include, resource_object} = ResourceObject.serialize(view, resource, conn, options)
        {to_include, [resource_object | resource_objects]}
      end)

    add_included(%__MODULE__{document | data: data}, to_include)
  end

  defp serialize_data(%__MODULE__{} = document, view, resource, conn, options) do
    {to_include, data} = ResourceObject.serialize(view, resource, conn, options)

    add_included(%__MODULE__{document | data: data}, to_include)
  end

  defp add_included(%__MODULE__{} = document, to_include) do
    included =
      to_include
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    %__MODULE__{document | included: included}
  end

  defp serialize_jsonapi(%__MODULE__{} = document, _view, _resource, _conn, _options),
    do: %__MODULE__{document | jsonapi: %JSONAPIObject{}}

  defp serialize_links(
         %__MODULE__{} = document,
         view,
         resources,
         %Conn{assigns: %{jsonapi_query: %Config{} = config}} = conn,
         options
       )
       when is_list(resources) do
    links =
      resources
      |> view.links(conn)
      |> Map.merge(view.pagination_links(resources, conn, config.page, options))
      |> Map.merge(%{self: View.url_for_pagination(view, resources, conn, config.page)})

    %__MODULE__{document | links: links}
  end

  defp serialize_links(%__MODULE__{} = document, view, resource, conn, _options) do
    links =
      resource
      |> view.links(conn)
      |> Map.merge(%{self: View.url_for(view, resource, conn)})

    %__MODULE__{document | links: links}
  end

  defp serialize_meta(%__MODULE__{} = document, _resource, _view, _conn, _options, meta)
       when is_map(meta),
       do: %__MODULE__{document | meta: meta}

  defp serialize_meta(%__MODULE__{} = document, _resource, _view, _conn, _options, _meta),
    do: document

  @spec deserialize(View.t(), payload()) :: {:ok, t()} | {:error, :invalid}
  def deserialize(view, payload) do
    %__MODULE__{}
    |> deserialize_data(view, payload)
    |> deserialize_included(view, payload)
    |> deserialize_meta(view, payload)
    |> validate()
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data})
       when is_list(data) do
    %__MODULE__{document | data: Enum.map(data, &ResourceObject.deserialize(view, &1))}
  end

  defp deserialize_data(%__MODULE__{} = document, view, %{"data" => data})
       when is_map(data) do
    %__MODULE__{document | data: ResourceObject.deserialize(view, data)}
  end

  defp deserialize_data(%__MODULE__{} = document, _view, _payload),
    do: document

  defp deserialize_included(%__MODULE__{} = document, view, %{"included" => included})
       when is_list(included) do
    %__MODULE__{document | included: Enum.map(included, &ResourceObject.deserialize(view, &1))}
  end

  defp deserialize_included(%__MODULE__{} = document, _view, _payload),
    do: document

  defp deserialize_meta(%__MODULE__{} = document, _view, %{"meta" => meta})
       when is_map(meta),
       do: %__MODULE__{document | meta: meta}

  defp deserialize_meta(%__MODULE__{} = document, _view, _payload),
    do: document

  defp validate(%__MODULE__{errors: errors, included: included, meta: meta} = document)
       when (is_list(errors) and not is_list(included)) or is_map(meta),
       do: {:ok, document}

  defp validate(%__MODULE__{data: data, errors: errors, meta: meta} = document)
       when is_map(data) or (is_list(data) and not is_list(errors)) or is_map(meta),
       do: {:ok, document}

  defp validate(%__MODULE__{} = _document),
    do: {:error, :invalid}

  defimpl Jason.Encoder,
    for: [
      __MODULE__,
      ErrorObject,
      JSONAPIObject,
      LinksObject,
      ResourceObject,
      RelationshipObject
    ] do
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
