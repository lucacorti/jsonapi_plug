defmodule JSONAPIPlug.Document.LinkObject do
  @moduledoc """
  JSON:API Link Object

  https://jsonapi.org/format/#document-links
  """

  alias JSONAPIPlug.Document

  @type t :: %__MODULE__{href: String.t(), meta: Document.meta() | nil} | String.t()
  defstruct [:href, :meta]

  @spec parse(Document.payload()) :: t() | no_return()
  def parse(data) when is_binary(data), do: data

  def parse(data) when is_map(data) do
    %__MODULE__{}
    |> parse_href(data)
    |> parse_meta(data)
  end

  defp parse_href(%__MODULE__{} = link_object, %{"href" => href})
       when is_binary(href) and byte_size(href) > 0,
       do: %{link_object | href: href}

  defp parse_href(link_object, _data), do: link_object

  defp parse_meta(%__MODULE__{} = link_object, %{"meta" => meta}) when is_map(meta),
    do: %{link_object | meta: meta}

  defp parse_meta(link_object, _data), do: link_object
end
