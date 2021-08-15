defmodule JSONAPI.UnderscoreParameters do
  @moduledoc """
  Takes dasherized JSON:API params and deserializes them to underscored params. Add
  this to your API's pipeline to aid in dealing with incoming parameters such as query
  params or data.

  Note that this Plug will only underscore parameters when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Example

  %{
    "data" => %{
      "attributes" => %{
        "foo-bar" => true
      }
    }
  }

  are transformed to:

  %{
    "data" => %{
      "attributes" => %{
        "foo_bar" => true
      }
    }
  }

  Moreover, with a GET request like:

      GET /example?filters[dog-breed]=Corgi

  **Without** this Plug your index action would look like:

      def index(conn, %{"filters" => %{"dog-breed" => "Corgi"}})

  And **with** this Plug:

      def index(conn, %{"filters" => %{"dog_breed" => "Corgi"}})

  Your API's pipeline might look something like this:

      # e.g. a Phoenix app

      pipeline :api do
        plug JSONAPI.EnforceSpec
        plug JSONAPI.UnderscoreParameters
      end
  """

  alias JSONAPI.View
  alias Plug.Conn

  @doc false
  def init(opts), do: opts

  @doc false
  def call(%Conn{params: params} = conn, _opts) do
    if JSONAPI.mime_type() in Conn.get_req_header(conn, "content-type") do
      %Conn{conn | params: View.expand_fields(params, &JSONAPI.underscore/1)}
    else
      conn
    end
  end
end
