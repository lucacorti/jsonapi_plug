defmodule JSONAPI.Plug.Sort do
  @moduledoc """
  Plug for parsing the 'sort' JSON:API query parameter
  """

  alias JSONAPI.{Exceptions.InvalidQuery, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(
        %Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, query_params: query_params} = conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi,
      %JSONAPI{jsonapi | sort: parse_sort(jsonapi, query_params["sort"])}
    )
  end

  defp parse_sort(%JSONAPI{sort: sort}, nil), do: sort

  defp parse_sort(%JSONAPI{view: view}, sort) when is_binary(sort) do
    valid_sort_fields =
      view.attributes()
      |> Enum.map(&to_string(View.field_option(&1, :name) || View.field_name(&1)))

    sort
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn field ->
      [_, direction, name] = Regex.run(~r/(-?)(\S*)/, field)

      unless name in valid_sort_fields do
        raise InvalidQuery, type: view.type(), param: :sort, value: field
      end

      build_sort(direction, String.to_existing_atom(name))
    end)
  end

  defp parse_sort(%JSONAPI{view: view}, sort) do
    raise InvalidQuery, type: view.type(), param: :sort, value: inspect(sort)
  end

  defp build_sort("", field), do: [asc: field]
  defp build_sort("-", field), do: [desc: field]
end
