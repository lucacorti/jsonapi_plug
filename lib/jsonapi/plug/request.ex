defmodule JSONAPI.Plug.Request do
  @moduledoc """
  Implements parsing of JSON:API 1.0 requests.

  The purpose is to validate and encode incoming requests. This handles the request body document
  and query parameters for:

    * [sorts](http://jsonapi.org/format/#fetching-sorting)
    * [include](http://jsonapi.org/format/#fetching-includes)
    * [filtering](http://jsonapi.org/format/#fetching-filtering)
    * [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
    * [pagination](http://jsonapi.org/format/#fetching-pagination)

  To enable request deserialization add this plug to your plug pipeline/controller like this:

  ```
  plug JSONAPI.Plug.Request,
    sort: ~w(created_at title),
    view: MyApp.MyView
  ```

  If your connection receives a valid JSON:API request this plug will parse it into a `JSONAPI`
  struct that has all the validated and parsed fields and store it into the `Plug.Conn` private
  field `:jsonapi`. The final output will look similar to the following:

  ```
  %Plug.Conn{...
    private: %{...
      jsonapi: %JSONAPI{
        fields: %{"my-type" => [:id, :text], "comment" => [:id, :body],
        filter: %{"title" => "my title"} # Easily reduceable into ecto where clauses
        include: [comments: :user] # Easily insertable into a Repo.preload,
        options: [sort: ["created_at", "title"]],
        page: %{
          limit: limit,
          offset: offset,
          page: page,
          size: size,
          cursor: cursor
        }},
        request: %JSONAPI.Document{...},
        sort: [desc: :created_at] # Easily insertable into an ecto order_by,
        view: MyApp.MyView
      }
    }
  }
  ```

  You can then use the contents of the struct to generate a response.

  ## Sparse Fieldsets

  Sparse fieldsets are supported. By default your response will include all
  available fields. Note that loading data is left to you.
  The fields attribute of the `JSONAPI` struct contains requested fields for
  each resource type.

  ## Options
    * `:view` - The `JSONAPI.View` used to parse the request.
    * `:sort` - List of atoms which define which fields can be sorted on.
    * `:filter` - List of atoms which define which fields can be filtered on.
  """

  alias JSONAPI.{Document, Exceptions.InvalidQuery, View}
  alias Plug.Conn

  @type options :: %{String => list() | map() | String.t()}

  @behaviour Plug

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}} = conn, options) do
    {api, options} = Keyword.pop(options, :api, jsonapi.api)

    {view, options} = Keyword.pop(options, :view)

    unless view do
      raise "You must pass the :view option to JSONAPI.Plug.Request"
    end

    conn = Conn.fetch_query_params(conn)

    query = normalize_query_params(conn.query_params)

    jsonapi =
      jsonapi
      |> struct(api: api, options: Enum.into(options, %{}), view: view)
      |> parse_fields(query)
      |> parse_include(query)
      |> parse_filter(query)
      |> parse_sort(query)
      |> parse_page(query)
      |> parse_body(conn)

    Conn.put_private(conn, :jsonapi, jsonapi)
  end

  @doc false
  @spec parse_page(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_page(%JSONAPI{} = jsonapi, %{"page" => page}) when is_map(page),
    do: %JSONAPI{jsonapi | page: page}

  def parse_page(%JSONAPI{view: view}, %{"page" => value}) do
    raise(InvalidQuery,
      type: view.type(),
      param: :page,
      value: value
    )
  end

  def parse_page(jsonapi, _query),
    do: jsonapi

  @doc false
  @spec parse_filter(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_filter(%JSONAPI{} = jsonapi, %{"filter" => filter}) when is_map(filter),
    do: %JSONAPI{jsonapi | filter: filter}

  def parse_filter(%JSONAPI{view: view}, %{"filter" => value}) do
    raise(InvalidQuery,
      type: view.type(),
      param: :filter,
      value: value
    )
  end

  def parse_filter(jsonapi, _query), do: jsonapi

  @doc false
  @spec parse_fields(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_fields(%JSONAPI{view: view} = jsonapi, %{"fields" => fields}) when is_map(fields) do
    Enum.reduce(fields, jsonapi, fn {type, value}, jsonapi ->
      valid_fields =
        view
        |> attributes_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",", trim: true)
          |> Enum.map(&JSONAPI.recase(&1, :underscore))
          |> Enum.into(MapSet.new(), &String.to_existing_atom/1)
        rescue
          ArgumentError ->
            reraise InvalidQuery.exception(
                      type: view.type(),
                      param: :fields,
                      value: value
                    ),
                    __STACKTRACE__
        end

      size = MapSet.size(requested_fields)

      case MapSet.subset?(requested_fields, valid_fields) do
        # no fields if empty - https://jsonapi.org/format/#fetching-sparse-fieldsets
        false when size > 0 ->
          bad_fields =
            requested_fields
            |> MapSet.difference(valid_fields)
            |> MapSet.to_list()
            |> Enum.join(",")

          raise InvalidQuery,
            type: view.type(),
            param: :fields,
            value: bad_fields

        _ ->
          %JSONAPI{
            jsonapi
            | fields: Map.put(jsonapi.fields, type, MapSet.to_list(requested_fields))
          }
      end
    end)
  end

  def parse_fields(%JSONAPI{view: view}, %{"fields" => value}) do
    raise(InvalidQuery,
      type: view.type(),
      param: :fields,
      value: value
    )
  end

  def parse_fields(jsonapi, _query), do: jsonapi

  defp attributes_for_type(view, type) do
    if type == view.type() do
      Enum.map(view.attributes(), &View.field_name/1)
    else
      case View.for_related_type(view, type) do
        nil -> raise InvalidQuery, type: view.type(), param: :fields, value: type
        related_view -> Enum.map(related_view.attributes(), &View.field_name/1)
      end
    end
  end

  @doc false
  @spec parse_sort(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_sort(%JSONAPI{options: options, view: view} = jsonapi, %{"sort" => sort}) do
    sort =
      sort
      |> String.split(",")
      |> Enum.map(fn field ->
        valid_sort = Map.get(options, :sort, [])
        [_, direction, field] = Regex.run(~r/(-?)(\S*)/, field)

        unless field in valid_sort do
          raise InvalidQuery, type: view.type(), param: :sort, value: field
        end

        build_sort(direction, String.to_existing_atom(field))
      end)
      |> List.flatten()

    %JSONAPI{jsonapi | sort: sort}
  end

  def parse_sort(jsonapi, _query), do: jsonapi

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]

  @doc false
  @spec parse_include(JSONAPI.t(), options()) :: JSONAPI.t() | no_return()
  def parse_include(%JSONAPI{view: view} = jsonapi, %{"include" => include}) do
    valid_includes = view.relationships()

    includes =
      include
      |> String.split(",")
      |> Enum.filter(&(byte_size(&1) > 0))
      |> Enum.map(&JSONAPI.recase(&1, :underscore))
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
                          type: view.type(),
                          param: :include,
                          value: inc
                        ),
                        __STACKTRACE__
            end

          if Enum.any?(valid_includes, fn {key, _val} -> key == inc end) do
            [inc]
          else
            raise InvalidQuery, type: view.type(), param: :include, value: inc
          end
        end
      end)

    %JSONAPI{jsonapi | include: includes}
  end

  def parse_include(jsonapi, _query), do: jsonapi

  defp handle_nested_include(key, valid_include, %JSONAPI{} = jsonapi) do
    keys =
      try do
        key
        |> String.split(".")
        |> Enum.map(&String.to_existing_atom/1)
      rescue
        ArgumentError ->
          reraise InvalidQuery.exception(
                    type: jsonapi.view.type(),
                    param: :include,
                    value: key
                  ),
                  __STACKTRACE__
      end

    if member_of_tree?(keys, valid_include) do
      last = List.last(keys)
      path = Enum.slice(keys, 0, Enum.count(keys) - 1)
      put_as_tree([], path, last)
    else
      raise InvalidQuery, type: jsonapi.view.type(), param: :include, value: key
    end
  end

  @spec parse_body(JSONAPI.t(), Conn.t()) :: JSONAPI.t()
  defp parse_body(%JSONAPI{} = jsonapi, conn),
    do: %JSONAPI{jsonapi | request: Document.deserialize(jsonapi.view, conn)}

  @doc false
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
      view = include[path][:view]
      member_of_tree?(tail, view.relationships())
    else
      false
    end
  end

  @doc """
  Normalizes query parameters to underscore form

  ## Examples

  ```
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
  ```
  """
  @spec normalize_query_params(String.t() | atom() | tuple() | map() | list()) :: map()
  def normalize_query_params(params) when is_map(params),
    do: Enum.into(params, %{}, &normalize_query_params/1)

  def normalize_query_params(params) when is_list(params),
    do: Enum.map(params, &normalize_query_params/1)

  def normalize_query_params({key, value}) when is_map(value),
    do: {JSONAPI.recase(key, :underscore), normalize_query_params(value)}

  def normalize_query_params({key, values}) when is_list(values) do
    {
      JSONAPI.recase(key, :underscore),
      Enum.map(values, fn
        string when is_binary(string) -> string
        value -> normalize_query_params(value)
      end)
    }
  end

  def normalize_query_params({key, value}),
    do: {JSONAPI.recase(key, :underscore), value}

  def normalize_query_params(value) when is_binary(value) or is_atom(value),
    do: JSONAPI.recase(value, :underscore)

  def normalize_query_params(value), do: value
end
