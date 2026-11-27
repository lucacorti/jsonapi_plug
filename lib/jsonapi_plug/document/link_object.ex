defmodule JSONAPIPlug.Document.LinkObject do
  @moduledoc """
  JSON:API Link Object

  https://jsonapi.org/format/#document-links
  """

  alias JSONAPIPlug.Document

  @type t ::
          %__MODULE__{
            describedby: String.t() | nil,
            href: String.t() | nil,
            hreflang: String.t() | [String.t()] | nil,
            meta: Document.meta() | nil,
            rel: String.t() | nil,
            title: String.t() | nil,
            type: String.t() | nil
          }
          | String.t()

  defstruct [:describedby, :href, :hreflang, :meta, :rel, :title, :type]

  @spec deserialize(Document.payload()) :: t() | no_return()
  def deserialize(data) when is_binary(data), do: data

  def deserialize(data) when is_map(data) do
    %__MODULE__{
      describedby: deserialize_describedby(data),
      href: deserialize_href(data),
      hreflang: deserialize_hreflang(data),
      meta: deserialize_meta(data),
      rel: deserialize_rel(data),
      title: deserialize_title(data),
      type: deserialize_type(data)
    }
  end

  defp deserialize_describedby(%{"describedby" => describedby})
       when is_binary(describedby) and byte_size(describedby) > 0,
       do: describedby

  defp deserialize_describedby(_data), do: nil

  defp deserialize_href(%{"href" => href}) when is_binary(href) and byte_size(href) > 0, do: href
  defp deserialize_href(_data), do: nil

  defp deserialize_hreflang(%{"hreflang" => hreflang})
       when is_binary(hreflang) and byte_size(hreflang) > 0,
       do: hreflang

  defp deserialize_hreflang(%{"hreflang" => hreflang}) when is_list(hreflang), do: hreflang
  defp deserialize_hreflang(_data), do: nil

  defp deserialize_meta(%{"meta" => meta}) when is_map(meta), do: meta
  defp deserialize_meta(_data), do: nil

  defp deserialize_rel(%{"rel" => rel}) when is_binary(rel) and byte_size(rel) > 0, do: rel
  defp deserialize_rel(_data), do: nil

  defp deserialize_title(%{"title" => title}) when is_binary(title) and byte_size(title) > 0,
    do: title

  defp deserialize_title(_data), do: nil

  defp deserialize_type(%{"type" => type}) when is_binary(type) and byte_size(type) > 0,
    do: type

  defp deserialize_type(_data), do: nil

  @spec serialize(t()) :: t()
  def serialize(link_object), do: link_object
end
