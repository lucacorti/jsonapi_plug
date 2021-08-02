defmodule JSONAPI.Document.ErrorObject do
  @moduledoc """
  JSON:API Error Object

  See https://jsonapi.org/format/#error-objects
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          links: %{String.t() => String.t()} | nil,
          status: String.t() | nil,
          code: String.t() | nil,
          title: String.t() | nil,
          detail: String.t() | nil,
          source: %{String.t() => String.t()} | nil,
          meta: %{String.t() => String.t()} | nil
        }
  defstruct id: nil,
            links: nil,
            status: nil,
            code: nil,
            title: nil,
            detail: nil,
            source: nil,
            meta: nil
end
