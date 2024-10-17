defmodule JSONAPIPlug.Document.LinkObject do
  @moduledoc """
  JSON:API Link Object

  https://jsonapi.org/format/#document-links
  """

  alias JSONAPIPlug.Document

  @type t :: %__MODULE__{href: String.t(), meta: Document.meta() | nil} | String.t()
  defstruct [:href, :meta]

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) when is_binary(data), do: data

  def deserialize(data) when is_map(data) do
    %__MODULE__{href: deserialize_href(data), meta: deserialize_meta(data)}
  end

  defp deserialize_href(%{"href" => href}) when is_binary(href) and byte_size(href) > 0, do: href
  defp deserialize_href(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta
  defp deserialize_meta(_data), do: nil

  @spec serialize(t()) :: t()
  def serialize(link_object), do: link_object
end
