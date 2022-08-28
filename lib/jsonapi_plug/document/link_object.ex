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
    %__MODULE__{}
    |> deserialize_href(data)
    |> deserialize_meta(data)
  end

  defp deserialize_href(%__MODULE__{} = link_object, %{"href" => href})
       when is_binary(href) and byte_size(href) > 0,
       do: %__MODULE__{link_object | href: href}

  defp deserialize_href(link_object, _data), do: link_object

  defp deserialize_meta(link_object, %{"meta" => meta}) when is_map(meta),
    do: %__MODULE__{link_object | meta: meta}

  defp deserialize_meta(link_object, _data), do: link_object

  @spec serialize(t()) :: t()
  def serialize(link_object), do: link_object
end
