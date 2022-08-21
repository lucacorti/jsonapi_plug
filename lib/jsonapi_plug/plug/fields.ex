defmodule JSONAPIPlug.Plug.Fields do
  @moduledoc """
  Plug for parsing the 'fields' JSON:API query parameter
  """

  alias JSONAPIPlug.{Exceptions.InvalidQuery, View}
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(
        %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}, query_params: query_params} =
          conn,
        _opts
      ) do
    Conn.put_private(
      conn,
      :jsonapi_plug,
      %JSONAPIPlug{jsonapi_plug | fields: parse_fields(jsonapi_plug, query_params["fields"])}
    )
  end

  defp parse_fields(%JSONAPIPlug{fields: fields}, nil), do: fields

  defp parse_fields(%JSONAPIPlug{view: view}, fields) when is_map(fields) do
    Enum.reduce(fields, %{}, fn {type, value}, fields ->
      valid_fields =
        view
        |> attributes_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",", trim: true)
          |> Enum.into(
            MapSet.new(),
            &String.to_existing_atom(JSONAPIPlug.recase(&1, :underscore))
          )
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
          Map.put(fields, type, MapSet.to_list(requested_fields))
      end
    end)
  end

  defp parse_fields(%JSONAPIPlug{view: view}, fields) do
    raise InvalidQuery, type: view.type(), param: :fields, value: fields
  end

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
end
