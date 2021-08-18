defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  alias JSONAPI.{Document, Resource, View}
  alias Plug.Conn

  @type t :: module()

  @type options :: Keyword.t()

  @type params :: %{String.t() => String.t()}

  @callback paginate(
              View.t(),
              [Resource.t()],
              Conn.t() | nil,
              params(),
              View.options()
            ) :: Document.links()

  @spec url_for(
          View.t(),
          [Resource.t()],
          Conn.t() | nil,
          params() | nil
        ) ::
          String.t()
  def url_for(
        view,
        resources,
        %Conn{query_params: query_params} = conn,
        nil = _params
      ) do
    query =
      query_params
      |> to_list_of_query_string_components()
      |> URI.encode_query()

    prepare_url(view, resources, conn, query)
  end

  def url_for(
        view,
        resources,
        %Conn{query_params: query_params} = conn,
        params
      ) do
    url_for(
      view,
      resources,
      %Conn{conn | query_params: Map.put(query_params, "page", params)},
      nil
    )
  end

  defp prepare_url(view, resources, conn, "" = _query), do: View.url_for(view, resources, conn)

  defp prepare_url(view, resources, conn, query) do
    view
    |> View.url_for(resources, conn)
    |> URI.parse()
    |> struct(query: query)
    |> URI.to_string()
  end

  defp to_list_of_query_string_components(map) when is_map(map) do
    Enum.flat_map(map, &do_to_list_of_query_string_components/1)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_list(value) do
    to_list_of_two_elem_tuple(key, value)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_map(value) do
    Enum.flat_map(value, fn {k, v} -> to_list_of_two_elem_tuple("#{key}[#{k}]", v) end)
  end

  defp do_to_list_of_query_string_components({key, value}),
    do: to_list_of_two_elem_tuple(key, value)

  defp to_list_of_two_elem_tuple(key, value) when is_list(value) do
    Enum.map(value, &{"#{key}[]", &1})
  end

  defp to_list_of_two_elem_tuple(key, value) do
    [{key, value}]
  end
end
