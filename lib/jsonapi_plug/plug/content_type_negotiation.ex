defmodule JSONAPIPlug.Plug.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type` and `accept` headers.

  The proper jsonapi.org content type is `application/vnd.api+json` as per
  [the specification](http://jsonapi.org/format/#content-negotiation-servers).

  As of JSON:API 1.1, the `ext` and `profile` media type parameters are supported:

  - `ext`: Specifies extensions. The server validates that all listed extension URIs are
    supported and responds with 415 if any are unsupported.
  - `profile`: Specifies profiles. Profiles are always accepted (unknown profiles are ignored).

  Any other media type parameters are rejected with 415.
  """

  alias JSONAPIPlug.Exceptions.InvalidHeader
  alias Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"],
    do: conn

  def call(conn, _opts) do
    conn |> validate_content_type() |> validate_accept()
  end

  # Parse a single media type entry.
  # Returns {:ok, params} | :not_jsonapi | :invalid_param
  defp parse_jsonapi_entry(entry) do
    case Conn.Utils.media_type(String.trim(entry)) do
      {:ok, "application", "vnd.api+json", params} -> check_params(params)
      _ -> :not_jsonapi
    end
  end

  defp check_params(params) do
    case Enum.find(params, fn {k, _v} -> k not in ["ext", "profile"] end) do
      nil -> {:ok, params}
      _ -> :invalid_param
    end
  end

  defp split_media_types(header_value), do: String.split(header_value, ",", trim: true)

  defp supported_extensions(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{config: config}}})
       when not is_nil(config),
       do: config[:extensions] || []

  defp supported_extensions(_conn), do: []

  defp validate_content_type(conn) do
    conn
    |> Conn.get_req_header("content-type")
    |> List.first()
    |> do_validate_content_type(conn)
  end

  defp do_validate_content_type(nil, conn), do: conn

  defp do_validate_content_type(raw_header, conn) do
    raw_header
    |> split_media_types()
    |> classify_content_type_header()
    |> apply_content_type_result(conn, raw_header)
  end

  defp classify_content_type_header(entries) do
    results = Enum.map(entries, &parse_jsonapi_entry/1)

    cond do
      Enum.any?(results, &match?({:ok, _}, &1)) -> :ok
      Enum.any?(results, &(&1 == :invalid_param)) -> :invalid_param
      true -> nil
    end
  end

  defp apply_content_type_result(:ok, conn, raw_header),
    do: validate_content_type_ext(conn, raw_header)

  defp apply_content_type_result(:invalid_param, _conn, _raw_header) do
    raise InvalidHeader,
      status: :unsupported_media_type,
      message:
        "The 'content-type' request header must contain the JSON:API mime type " <>
          "(#{JSONAPIPlug.mime_type()}) without parameters other than 'ext' or 'profile'",
      reference: "https://jsonapi.org/format/#content-negotiation.",
      header: "content-type"
  end

  defp apply_content_type_result(nil, _conn, _raw_header) do
    raise InvalidHeader,
      status: :unsupported_media_type,
      message:
        "The 'content-type' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()})",
      reference: "https://jsonapi.org/format/#content-negotiation.",
      header: "content-type"
  end

  # Second pass: check that any ext URIs in content-type are all supported
  defp validate_content_type_ext(conn, raw_header) do
    supported = supported_extensions(conn)

    if content_type_has_unsupported_ext?(raw_header, supported) do
      raise InvalidHeader,
        status: :unsupported_media_type,
        message: "The 'content-type' request header contains an unsupported extension URI",
        reference: "https://jsonapi.org/format/#content-negotiation-servers",
        header: "content-type"
    else
      conn
    end
  end

  defp content_type_has_unsupported_ext?(raw_header, supported) do
    Enum.any?(split_media_types(raw_header), &entry_has_unsupported_ext?(&1, supported))
  end

  defp entry_has_unsupported_ext?(entry, supported) do
    case parse_jsonapi_entry(entry) do
      {:ok, %{"ext" => ext_value}} -> has_unsupported_uri?(ext_value, supported)
      _ -> false
    end
  end

  defp has_unsupported_uri?(ext_value, supported) do
    ext_value
    |> String.split(" ", trim: true)
    |> Enum.any?(fn uri -> uri not in supported end)
  end

  defp validate_accept(conn) do
    conn
    |> Conn.get_req_header("accept")
    |> List.first()
    |> do_validate_accept(conn)
  end

  defp do_validate_accept(nil, conn), do: conn

  defp do_validate_accept(raw_header, conn) do
    supported = supported_extensions(conn)

    classified =
      raw_header |> split_media_types() |> Enum.map(&classify_accept_entry(&1, supported))

    apply_accept_result(conn, classified)
  end

  defp classify_accept_entry(entry, supported) do
    case parse_jsonapi_entry(entry) do
      {:ok, params} when map_size(params) == 0 -> :valid
      {:ok, %{"profile" => _}} -> :profile_only
      {:ok, %{"ext" => ext_value}} -> classify_ext(ext_value, supported)
      {:ok, %{"ext" => ext_value, "profile" => _}} -> classify_ext(ext_value, supported)
      :not_jsonapi -> :not_jsonapi
      :invalid_param -> :invalid_param
    end
  end

  defp classify_ext(ext_value, supported) do
    uris = String.split(ext_value, " ", trim: true)
    if Enum.all?(uris, &(&1 in supported)), do: :valid, else: :unsupported_ext
  end

  defp apply_accept_result(conn, classified) do
    jsonapi_entries = Enum.reject(classified, &(&1 == :not_jsonapi))

    cond do
      Enum.any?(classified, &(&1 in [:valid, :profile_only])) ->
        conn

      Enum.all?(classified, &(&1 == :not_jsonapi)) ->
        conn

      jsonapi_entries != [] and
          Enum.all?(jsonapi_entries, &(&1 in [:unsupported_ext, :invalid_param])) ->
        raise InvalidHeader,
          status: :not_acceptable,
          message:
            "The 'accept' request header does not contain any acceptable JSON:API media type",
          reference: "https://jsonapi.org/format/#content-negotiation",
          header: "accept"

      true ->
        raise InvalidHeader,
          status: :not_acceptable,
          message:
            "The 'accept' request header must contain the JSON:API mime type (#{JSONAPIPlug.mime_type()})",
          reference: "https://jsonapi.org/format/#content-negotiation",
          header: "accept"
    end
  end
end
