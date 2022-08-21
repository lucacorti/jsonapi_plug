defmodule JSONAPI.Normalizer.Params do
  @moduledoc """
  Interface to normalize user data to and from a JSON:API Document
  """
  alias JSONAPI.{Document, View}
  alias Plug.Conn

  @type data :: Document.payload()
  @type meta :: Document.payload()

  @doc "Transforms a JSON:API Document into params"
  @callback denormalize(Document.t(), View.t(), Conn.t()) :: Conn.params() | no_return()

  @doc "Transforms user data into a JSON:API Document"
  @callback normalize(View.t(), Conn.t() | nil, data() | nil, meta() | nil, View.options()) ::
              Document.t() | no_return()
end
