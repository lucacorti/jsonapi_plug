defmodule JSONAPIPlug.Pagination do
  @moduledoc """
  JSON:API Pagination strategy

  https://jsonapi.org/format/#fetching-pagination

  Pagination links can be generated by implementing a module conforming to the
  `JSONAPIPlug.Pagination` behavior and configuring the `pagination` of your API module:

  ```elixir
  defmodule MyApp.MyController do
    plug JSONAPIPlug.Plug, api: MyApp.MyApi, resource: MyApp.MyView
  end
  ```

  ```elixir
  config :my_app, MyApp.API, pagination: MyApp.MyPagination
  ```

  Actual pagination needs to be handled by your application and is outside the scope of this library.

  Links can be generated using the `JSONAPIPlug.page` information stored in the connection `jsonapi_plug` private field
  and by passing additional information to your pagination module by passing `options` from your controller.

  See the tests for an example implementation of page based pagination strategy.
  """

  alias JSONAPIPlug.{Document.LinkObject, View}
  alias Plug.Conn

  @type t :: module()
  @type link :: :first | :last | :next | :prev
  @type links :: %{link() => String.t()}
  @type options :: Keyword.t()
  @type params :: %{String.t() => String.t()}

  @callback paginate(
              View.t(),
              [View.resource()],
              Conn.t() | nil,
              params(),
              View.options()
            ) :: links()

  @spec url_for(
          View.t(),
          [View.resource()],
          Conn.t() | nil,
          params() | nil
        ) ::
          LinkObject.t()
  def url_for(
        resource,
        data,
        %Conn{query_params: query_params} = conn,
        nil = _params
      ) do
    query =
      query_params
      |> to_list_of_query_string_components()
      |> URI.encode_query()

    prepare_url(resource, data, conn, query)
  end

  def url_for(
        resource,
        data,
        %Conn{query_params: query_params} = conn,
        params
      ) do
    url_for(
      resource,
      data,
      %Conn{conn | query_params: Map.put(query_params, "page", params)},
      nil
    )
  end

  defp prepare_url(resource, data, conn, "" = _query),
    do: View.url_for(resource, data, conn)

  defp prepare_url(resource, data, conn, query) do
    resource
    |> View.url_for(data, conn)
    |> URI.parse()
    |> struct(query: query)
    |> URI.to_string()
  end

  defp to_list_of_query_string_components(map) when is_map(map),
    do: Enum.flat_map(map, &do_to_list_of_query_string_components/1)

  defp do_to_list_of_query_string_components({key, value}) when is_list(value),
    do: to_list_of_two_elem_tuple(key, value)

  defp do_to_list_of_query_string_components({key, value}) when is_map(value),
    do: Enum.flat_map(value, fn {k, v} -> to_list_of_two_elem_tuple("#{key}[#{k}]", v) end)

  defp do_to_list_of_query_string_components({key, value}),
    do: to_list_of_two_elem_tuple(key, value)

  defp to_list_of_two_elem_tuple(key, value) when is_list(value),
    do: Enum.map(value, &{"#{key}[]", &1})

  defp to_list_of_two_elem_tuple(key, value), do: [{key, value}]
end
