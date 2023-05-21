defmodule JSONAPIPlug do
  @moduledoc """
  JSONAPIPlug context

  This defines a struct for storing configuration and request data. `JSONAPIPlug.Plug` populates
  its attributes by means of a number of other plug modules used to parse and validate requests
  and stores it in the `Plug.Conn` private assings under the `jsonapi_plug` key.
  """

  alias Plug.Conn
  alias JSONAPIPlug.{API, Resource}

  @type t :: %__MODULE__{
          api: API.t(),
          fields: term(),
          filter: term(),
          include: term(),
          page: term(),
          params: Conn.params(),
          resource: Resource.t(),
          sort: term()
        }
  defstruct api: nil,
            fields: nil,
            filter: nil,
            include: nil,
            page: nil,
            params: nil,
            resource: nil,
            sort: nil

  @doc """
  JSON:API MIME type

  Returns the JSON:API MIME type.
  """
  @spec mime_type :: String.t()
  def mime_type, do: "application/vnd.api+json"
end
