defmodule JSONAPI.Plug.Request do
  @moduledoc """
  Implements a fully JSONAPI V1 spec for parsing a complex query string and
  returning Elixir datastructures. The purpose is to validate and encode incoming
  queries and fail quickly.

  Primarialy this handles:
    * [sorts](http://jsonapi.org/format/#fetching-sorting)
    * [include](http://jsonapi.org/format/#fetching-includes)
    * [filtering](http://jsonapi.org/format/#fetching-filtering)
    * [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
    * [pagination](http://jsonapi.org/format/#fetching-pagination)

  This Plug works in conjunction with a `JSONAPI.View` as well as some Plug
  defined configuration.

  In your controller you may add:

  ```
  plug JSONAPI.Request,
    filter: ~w(title),
    sort: ~w(created_at title),
    view: MyPostView
  ```

  If your controller's index function receives a query with params inside those
  bounds it will build a `JSONAPI` that has all the validated and parsed
  fields for your usage. The final configuration will be added to assigns
  `jsonapi`.

  The final output will be a `JSONAPI` struct and will look similar to the
  following:

      %JSONAPI{
        view: MyPostView,
        opts: [sort: ["created_at", "title"], filter: ["title"]],
        sort: [desc: :created_at] # Easily insertable into an ecto order_by,
        filter: [title: "my title"] # Easily reduceable into ecto where clauses
        include: [comments: :user] # Easily insertable into a Repo.preload,
        fields: %{"myview" => [:id, :text], "comment" => [:id, :body],
        page: %{
          limit: limit,
          offset: offset,
          page: page,
          size: size,
          cursor: cursor
        }}
      }

  The final result should allow you to build a query quickly and with little overhead.

  ## Sparse Fieldsets

  Sparse fieldsets are supported. By default your response will include all
  available fields. Note that the query to your database is left to you. Should
  you want to query your DB for specific fields `JSONAPI.fields` will
  return the requested fields for each resource (see above example).

  ## Options
    * `:view` - The JSONAPI View which is the basis for this plug.
    * `:sort` - List of atoms which define which fields can be sorted on.
    * `:filter` - List of atoms which define which fields can be filtered on.
  """

  alias JSONAPI.{Document, Exceptions.InvalidQuery, Resource.Field, View}
  alias Plug.Conn

  @type options :: %{String => list() | map() | String.t()}

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{assigns: %{jsonapi: %JSONAPI{api: api} = jsonapi}} = conn, opts) do
    {api, opts} = Keyword.pop(opts, :api, api)

    {view, opts} = Keyword.pop(opts, :view)

    unless view do
      raise "You must pass the :view option to JSONAPI.Request"
    end

    conn = Conn.fetch_query_params(conn)

    query =
      conn
      |> Map.get(:query_params)
      |> normalize_query_params()

    jsonapi =
      jsonapi
      |> struct(api: api, opts: Enum.into(opts, %{}), view: view)
      |> parse_fields(query)
      |> parse_include(query)
      |> parse_filter(query)
      |> parse_sort(query)
      |> parse_pagination(query)

    Conn.assign(conn, :jsonapi, %JSONAPI{jsonapi | request: Document.deserialize(view, conn)})
  end

  @spec parse_pagination(JSONAPI.t(), options()) :: JSONAPI.t()
  def parse_pagination(%JSONAPI{} = jsonapi, %{"page" => page}) when is_map(page),
    do: %JSONAPI{jsonapi | page: page}

  def parse_pagination(jsonapi, _query),
    do: jsonapi

  @spec parse_filter(JSONAPI.t(), options()) :: JSONAPI.t()
  def parse_filter(%JSONAPI{opts: opts, view: view} = jsonapi, %{"filter" => filter})
      when is_map(filter) do
    opts_filter = Keyword.get(opts, :filter, [])

    Enum.reduce(filter, jsonapi, fn {key, val}, jsonapi ->
      unless key in opts_filter do
        raise InvalidQuery, resource: view.type(), param: key, param_type: :filter
      end

      %JSONAPI{jsonapi | filter: Keyword.put(jsonapi.filter, String.to_existing_atom(key), val)}
    end)
  end

  def parse_filter(jsonapi, _query),
    do: jsonapi

  @spec parse_fields(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_fields(%JSONAPI{view: view} = jsonapi, %{"fields" => fields}) when is_map(fields) do
    Enum.reduce(fields, jsonapi, fn {type, value}, jsonapi ->
      valid_fields =
        view
        |> get_valid_attributes_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",")
          |> Enum.map(&Field.inflect(&1, :underscore))
          |> Enum.into(MapSet.new(), &String.to_existing_atom/1)
        rescue
          ArgumentError ->
            reraise InvalidQuery.exception(
                      resource: view.type(),
                      param: value,
                      param_type: :fields
                    ),
                    __STACKTRACE__
        end

      unless MapSet.subset?(requested_fields, valid_fields) do
        bad_fields =
          requested_fields
          |> MapSet.difference(valid_fields)
          |> MapSet.to_list()
          |> Enum.join(",")

        raise InvalidQuery,
          resource: view.type(),
          message: "invalid fields, #{value} for type #{view.type()}",
          param: bad_fields,
          param_type: :fields
      end

      %JSONAPI{jsonapi | fields: Map.put(jsonapi.fields, type, MapSet.to_list(requested_fields))}
    end)
  end

  def parse_fields(jsonapi, _query), do: jsonapi

  defp get_valid_attributes_for_type(view, type) do
    if type == view.type() do
      view.attributes(view.resource())
    else
      case View.for_related_type(view, type) do
        nil -> raise InvalidQuery, resource: view.type(), param: type, param_type: :fields
        view -> view.attributes(view.resource())
      end
    end
  end

  @spec parse_sort(JSONAPI.t(), options()) :: JSONAPI.t()
  def parse_sort(%JSONAPI{opts: opts, view: view} = jsonapi, %{"sort" => sort}) do
    sort =
      sort
      |> String.split(",")
      |> Enum.map(fn field ->
        valid_sort = Keyword.get(opts, :sort, [])
        [_, direction, field] = Regex.run(~r/(-?)(\S*)/, field)

        unless field in valid_sort do
          raise InvalidQuery, resource: view.type(), param: field, param_type: :sort
        end

        build_sort(direction, String.to_existing_atom(field))
      end)
      |> List.flatten()

    %JSONAPI{jsonapi | sort: sort}
  end

  def parse_sort(jsonapi, _query), do: jsonapi

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]

  @spec parse_include(JSONAPI.t(), options()) :: JSONAPI.t()
  def parse_include(%JSONAPI{view: view} = jsonapi, %{"include" => include}) do
    valid_includes = view.relationships(view.resource())

    includes =
      include
      |> String.split(",")
      |> Enum.map(&Field.inflect(&1, :underscore))
      |> Enum.flat_map(fn inc ->
        if inc =~ ~r/\w+\.\w+/ do
          handle_nested_include(inc, valid_includes, jsonapi)
        else
          inc =
            try do
              String.to_existing_atom(inc)
            rescue
              ArgumentError ->
                reraise InvalidQuery.exception(
                          resource: view.type(),
                          param: inc,
                          param_type: :include
                        ),
                        __STACKTRACE__
            end

          if Enum.any?(valid_includes, fn {key, _val} -> key == inc end) do
            [inc]
          else
            raise InvalidQuery, resource: view.type(), param: inc, param_type: :include
          end
        end
      end)

    %JSONAPI{jsonapi | include: includes}
  end

  def parse_include(jsonapi, _query), do: jsonapi

  defp handle_nested_include(key, valid_include, %JSONAPI{view: view}) do
    keys =
      try do
        key
        |> String.split(".")
        |> Enum.map(&String.to_existing_atom/1)
      rescue
        ArgumentError ->
          reraise InvalidQuery.exception(
                    resource: view.type(),
                    param: key,
                    param_type: :include
                  ),
                  __STACKTRACE__
      end

    last = List.last(keys)
    path = Enum.slice(keys, 0, Enum.count(keys) - 1)

    if member_of_tree?(keys, valid_include) do
      put_as_tree([], path, last)
    else
      raise InvalidQuery, resource: view.type(), param: key, param_type: :include
    end
  end

  @spec put_as_tree(term(), term(), term()) :: term()
  def put_as_tree(acc, items, val) do
    [head | tail] = Enum.reverse(items)
    build_tree(Keyword.put(acc, head, val), tail)
  end

  defp build_tree(acc, []), do: acc

  defp build_tree(acc, [head | tail]) do
    build_tree(Keyword.put([], head, acc), tail)
  end

  defp member_of_tree?([], _thing), do: true
  defp member_of_tree?(_thing, []), do: false

  defp member_of_tree?([path | tail], include) when is_list(include) do
    if Keyword.has_key?(include, path) do
      view = include[path]
      member_of_tree?(tail, view.relationships(view.resource()))
    else
      false
    end
  end

  @doc """
  iex> normalize_query_params(%{"foo-bar" => "baz"})
  %{"foo_bar" => "baz"}

  iex> normalize_query_params(%{"fooBar" => "baz"})
  %{"foo_bar" => "baz"}

  iex> normalize_query_params(%{"foo_bar" => "baz"})
  %{"foo_bar" => "baz"}

  iex> normalize_query_params({"foo-bar", "dollar-sol"})
  {"foo_bar", "dollar-sol"}

  iex> normalize_query_params({"foo-bar", %{"a-d" => "z-8"}})
  {"foo_bar", %{"a_d" => "z-8"}}

  iex> normalize_query_params(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"})
  %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

  iex> normalize_query_params(%{"f-b" => %{"a-d" => %{"z-w" => "z"}}, "c-d" => "e"})
  %{"f_b" => %{"a_d" => %{"z_w" => "z"}}, "c_d" => "e"}

  iex> normalize_query_params(:"foo-bar")
  "foo_bar"

  iex> normalize_query_params(:fooBar)
  "foo_bar"

  iex> normalize_query_params(:foo_bar)
  "foo_bar"

  iex> normalize_query_params(%{"f-b" => "a-d"})
  %{"f_b" => "a-d"}

  iex> normalize_query_params(%{"xValue" => 123})
  %{"x_value" => 123}

  iex> normalize_query_params(%{"attributes" => %{"corgiName" => "Wardel"}})
  %{"attributes" => %{"corgi_name" => "Wardel"}}

  iex> normalize_query_params(%{"attributes" => %{"corgiName" => ["Wardel"]}})
  %{"attributes" => %{"corgi_name" => ["Wardel"]}}

  iex> normalize_query_params(%{"attributes" => %{"someField" => ["SomeValue", %{"nestedField" => "Value"}]}})
  %{"attributes" => %{"some_field" => ["SomeValue", %{"nested_field" => "Value"}]}}

  iex> normalize_query_params([%{"fooBar" => "a"}, %{"fooBar" => "b"}])
  [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

  iex> normalize_query_params([%{"foo_bar" => "a"}, %{"foo_bar" => "b"}])
  [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

  iex> normalize_query_params(%{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]})
  %{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}
  """
  @spec normalize_query_params(String.t() | atom() | tuple() | map() | list()) :: map()
  def normalize_query_params(map) when is_map(map),
    do: Enum.into(map, %{}, &normalize_query_params/1)

  def normalize_query_params(values) when is_list(values),
    do: Enum.map(values, &normalize_query_params/1)

  def normalize_query_params({key, value}) when is_map(value),
    do: {Field.inflect(key, :underscore), normalize_query_params(value)}

  def normalize_query_params({key, values}) when is_list(values) do
    {
      Field.inflect(key, :underscore),
      Enum.map(values, fn
        string when is_binary(string) -> string
        value -> normalize_query_params(value)
      end)
    }
  end

  def normalize_query_params({key, value}),
    do: {Field.inflect(key, :underscore), value}

  def normalize_query_params(value) when is_binary(value) or is_atom(value),
    do: Field.inflect(value, :underscore)

  def normalize_query_params(value), do: value
end
