defprotocol JSONAPIPlug.Resource.Meta do
  @moduledoc """
  Resource Links

  Implement this protocol to generate JSON:API metadata for indivudual resources.
  Metadata returned will be included for each resource `meta` in JSON:API responses.

  This example implementation generates metadata for each `MyApp.Post` resource.

  ```elixir
    defimpl JSONAPIPlug.Resource.Meta, for: MyApp.Post do
      def meta(%@for{} = post, _conn), do: %{slug: to_slug(post.title)}

      defp to_slug(string), do: string  |> String.downcase |> String.replace(" ", "-")
    end
  ```
  """

  alias JSONAPIPlug.{Document, Resource}
  alias Plug.Conn

  @fallback_to_any true

  @doc """
  Resource meta

  Returns the resource meta to be returned for resources by the resource.
  """
  @spec meta(Resource.t(), Conn.t()) :: Document.meta() | nil
  def meta(resource, conn)
end

defimpl JSONAPIPlug.Resource.Meta, for: Any do
  def meta(_resource, _conn), do: nil
end
