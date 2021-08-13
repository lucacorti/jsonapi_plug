defmodule JSONAPI.Document.LinksObject do
  @moduledoc """
  JSON:API Links Object

  https://jsonapi.org/format/#document-links
  """

  alias JSONAPI.Document

  @type link :: t() | String.t()

  @type t :: %__MODULE__{href: String.t(), meta: Document.meta() | nil}
  defstruct [:href, :meta]
end
