defmodule JSONAPI.Document.ErrorObject do
  @moduledoc """
  JSON:API Error Object

  https://jsonapi.org/format/#error-objects
  """

  @type t :: %__MODULE__{
          code: String.t() | nil,
          detail: String.t() | nil,
          id: String.t() | nil,
          links: %{String.t() => String.t()} | nil,
          meta: %{String.t() => String.t()} | nil,
          source: %{pointer: String.t()} | nil,
          status: String.t() | nil,
          title: String.t() | nil
        }
  defstruct code: nil,
            detail: nil,
            id: nil,
            links: nil,
            meta: nil,
            source: nil,
            status: nil,
            title: nil
end
