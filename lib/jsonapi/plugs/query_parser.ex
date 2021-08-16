defmodule JSONAPI.QueryParser do
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
  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(created_at title),
    view: MyView
  ```

  If your controller's index function receives a query with params inside those
  bounds it will build a `JSONAPI.Config` that has all the validated and parsed
  fields for your usage. The final configuration will be added to assigns
  `jsonapi_query`.

  The final output will be a `JSONAPI.Config` struct and will look similar to the
  following:

      %JSONAPI.Config{
        view: MyView,
        opts: [view: MyView, sort: ["created_at", "title"], filter: ["title"]],
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
  you want to query your DB for specific fields `JSONAPI.Config.fields` will
  return the requested fields for each resource (see above example).

  ## Options
    * `:view` - The JSONAPI View which is the basis for this plug.
    * `:sort` - List of atoms which define which fields can be sorted on.
    * `:filter` - List of atoms which define which fields can be filtered on.

  ## Dasherized Fields

  Note that if your API is returning dasherized fields (e.g. `"dog-breed": "Corgi"`)
  we recommend that you include the `JSONAPI.UnderscoreParameters` Plug in your
  API's pipeline. This will underscore fields for easier operations in your code.

  For more details please see `JSONAPI.UnderscoreParameters`.
  """

  @behaviour Plug

  alias JSONAPI.{Config, Exceptions.InvalidQuery}
  alias Plug.Conn

  @impl Plug
  def init(opts) do
    view = Keyword.fetch!(opts, :view)
    struct(Config, opts: opts, view: view)
  end

  @impl Plug
  def call(conn, opts) do
    config =
      conn
      |> Conn.fetch_query_params()
      |> Map.get(:query_params)
      |> struct_from_map(%Config{})

    config =
      opts
      |> parse_fields(config)
      |> parse_include(config)
      |> parse_filter(config)
      |> parse_sort(config)
      |> parse_pagination(config)

    Conn.assign(conn, :jsonapi_query, config)
  end

  @spec parse_pagination(Config.t(), Config.t()) :: Config.t()
  def parse_pagination(config, %Config{page: page}) when map_size(page) == 0,
    do: config

  def parse_pagination(%Config{} = config, %Config{page: page}),
    do: %Config{config | page: page}

  @spec parse_filter(Config.t(), Config.t()) :: Config.t()
  def parse_filter(config, %Config{filter: filter}) when map_size(filter) == 0, do: config

  def parse_filter(%Config{opts: opts} = config, %Config{filter: filter}) do
    opts_filter = Keyword.get(opts, :filter, [])

    Enum.reduce(filter, config, fn {key, val}, config ->
      check_filter_validity!(opts_filter, key, config)
      %Config{config | filter: Keyword.put(config.filter, String.to_atom(key), val)}
    end)
  end

  defp check_filter_validity!(filters, key, config) do
    unless key in filters do
      raise InvalidQuery, resource: config.view.type(), param: key, param_type: :filter
    end
  end

  @spec parse_fields(Config.t(), Config.t()) :: Config.t() | no_return()
  def parse_fields(%Config{} = config, %Config{fields: fields}) when fields == %{},
    do: config

  def parse_fields(%Config{} = config, %Config{fields: fields}) do
    Enum.reduce(fields, config, fn {type, value}, config ->
      valid_fields =
        config
        |> get_valid_fields_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",")
          |> Enum.map(&JSONAPI.underscore/1)
          |> Enum.into(MapSet.new(), &String.to_existing_atom/1)
        rescue
          ArgumentError -> raise_invalid_field_names(value, config.view.type())
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

          raise_invalid_field_names(bad_fields, config.view.type())

        _ ->
          %{acc | fields: Map.put(acc.fields, type, MapSet.to_list(requested_fields))}
      end

      %Config{config | fields: Map.put(config.fields, type, MapSet.to_list(requested_fields))}
    end)
  end

  @spec parse_sort(Config.t(), Config.t()) :: Config.t()
  def parse_sort(config, %Config{sort: nil}), do: config

  def parse_sort(%Config{opts: opts} = config, %Config{sort: sort}) do
    sort =
      sort
      |> String.split(",")
      |> Enum.map(fn field ->
        valid_sort = Keyword.get(opts, :sort, [])
        [_, direction, field] = Regex.run(~r/(-?)(\S*)/, field)

        unless field in valid_sort do
          raise InvalidQuery, resource: config.view.type(), param: field, param_type: :sort
        end

        build_sort(direction, String.to_atom(field))
      end)
      |> List.flatten()

    %Config{config | sort: sort}
  end

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]

  @spec parse_include(Config.t(), Config.t()) :: Config.t()
  def parse_include(config, %Config{include: []}), do: config

  def parse_include(%Config{view: view} = config, %Config{include: include}) do
    valid_includes = view.relationships()

    includes =
      include
      |> String.split(",")
      |> Enum.map(&JSONAPI.underscore/1)
      |> Enum.flat_map(fn inc ->
        if inc =~ ~r/\w+\.\w+/ do
          handle_nested_include(inc, valid_includes, config)
        else
          inc =
            try do
              String.to_existing_atom(inc)
            rescue
              ArgumentError -> raise_invalid_include_query(inc, config.view.type())
            end

          if Enum.any?(valid_includes, fn {key, _val} -> key == inc end) do
            [inc]
          else
            raise_invalid_include_query(inc, config.view.type())
          end
        end
      end)

    %Config{config | include: includes}
  end

  @spec handle_nested_include(String.t(), list(), Config.t()) :: list() | no_return()
  def handle_nested_include(key, valid_include, config) do
    keys =
      try do
        key
        |> String.split(".")
        |> Enum.map(&String.to_existing_atom/1)
      rescue
        ArgumentError -> raise_invalid_include_query(key, config.view.type())
      end

    last = List.last(keys)
    path = Enum.slice(keys, 0, Enum.count(keys) - 1)

    if member_of_tree?(keys, valid_include) do
      put_as_tree([], path, last)
    else
      raise_invalid_include_query(key, config.view.type())
    end
  end

  @spec get_valid_fields_for_type(Config.t(), String.t()) :: list(atom())
  def get_valid_fields_for_type(%Config{view: view}, type) do
    if type == view.type() do
      view.attributes()
    else
      get_view_for_type(view, type).attributes()
    end
  end

  @spec get_view_for_type(module(), String.t()) :: module() | no_return()
  def get_view_for_type(view, type) do
    case Enum.find(view.relationships(), fn {_relationship, relationship_view} ->
           relationship_view.type() == type
         end) do
      {_, view} -> view
      nil -> raise_invalid_field_names(type, view.type())
    end
  end

  @spec raise_invalid_include_query(String.t(), String.t()) :: no_return()
  defp raise_invalid_include_query(param, resource_type) do
    raise InvalidQuery, resource: resource_type, param: param, param_type: :include
  end

  @spec raise_invalid_field_names(String.t(), String.t()) :: no_return()
  defp raise_invalid_field_names(bad_fields, resource_type) do
    raise InvalidQuery, resource: resource_type, param: bad_fields, param_type: :fields
  end

  defp struct_from_map(params, struct) do
    processed_map =
      for {struct_key, _} <- Map.from_struct(struct), into: %{} do
        case Map.get(params, to_string(struct_key)) do
          nil -> {false, false}
          value -> {struct_key, value}
        end
      end

    struct(struct, processed_map)
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
      member_of_tree?(tail, view.relationships())
    else
      false
    end
  end
end
