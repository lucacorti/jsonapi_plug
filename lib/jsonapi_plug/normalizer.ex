defmodule JSONAPIPlug.Normalizer do
  @moduledoc """
  Interface to normalize user data to and from a `JSON:API` Document

  You can implement your custom normalizer to convert your application
  data to and from the `JSONAPIPlug.Document` data structure:

  ```elixir
  defmodule MyApp.API.Normalizer
    ...

    @behaviour JSONAPIPlug.Normalizer

    # Transforms requests from `JSONAPIPlug.Document` to user data
    @impl JSONAPIPlug.Normalizer
    def denormalize(document, view, conn) do
      ...
    end

    # Transforms responsens from user data to `JSONAPIPlug.Document`
    @impl JSONAPIPlug.Normalizer
    def normalize(view, conn, data, meta, options) do
      ...
    end

    ...
  end
  ```

  and by configuring in in your api configuration:

  ```elixir
  config :my_app, MyApp.API, normalizer: MyApp.API.Normalizer
  ```

  The normalizer takes the preparsed `JSONAPI.Document` as input and its return value
  replaces the conn `body_params` and is also placed in the conn `params` under a "data" key
  for use in your application logic.

  You can return an error during parsing by raising `JSONAPIPlug.Exceptions.InvalidDocument` at
  any point in your normalizer code.
  """
  alias JSONAPIPlug.{Document, View}
  alias Plug.Conn

  @type t :: module()

  @doc "Transforms a JSON:API Document user data"
  @callback denormalize(Document.t(), View.t(), Conn.t()) :: Conn.params() | no_return()

  @doc "Transforms user data into a JSON:API Document"
  @callback normalize(
              View.t(),
              Conn.t() | nil,
              View.data() | nil,
              View.meta() | nil,
              View.options()
            ) ::
              Document.t() | no_return()
end
