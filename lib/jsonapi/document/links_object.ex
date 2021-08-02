defmodule JSONAPI.Document.LinksObject do
  @moduledoc """
  JSON:API Links Object

  See https://jsonapi.org/format/#document-links
  """

  @type link :: String.t() | nil
  @type t :: %__MODULE__{
          first: link(),
          last: link(),
          next: link(),
          prev: link(),
          related: link(),
          self: link()
        }
  defstruct [:first, :last, :next, :prev, :related, :self]
end
