defprotocol JSONAPIPlug.Resource.Validator do
  @moduledoc """
  Resource Validator

  Implement this protocol to validate a JSON:API resource.
  Validation will be performed on resource attributes before normalizig them.

  This example implementation always accepts params regardless of what is received.

  ```elixir
    defimpl JSONAPIPlug.Resource.Validator, for: MyApp.Post do
      def validate(%@for{} = post, _params, _conn), do: :ok
    end
  ```
  """

  alias JSONAPIPlug.Document.{ErrorObject, ResourceObject}
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  @fallback_to_any true

  @doc """
  Validates the resource

  Returns `:ok` if the resource is valid, or `{:error, [ErrorObject.t()]}` if it is invalid.
  """
  @spec validate(Resource.t(), ResourceObject.attributes(), Conn.t()) ::
          :ok | {:error, [ErrorObject.t()]}
  def validate(resource, attributes, conn)
end

defimpl JSONAPIPlug.Resource.Validator, for: Any do
  alias JSONAPIPlug.Document.ErrorObject
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  def validate(_resource, _attributes, %Conn{method: "PATCH"}), do: :ok

  def validate(resource, attributes, %Conn{private: %{jsonapi_plug: jsonapi_plug}}) do
    case JSV.validate(attributes, Resource.schema(resource), cast: false) do
      {:ok, _data} ->
        :ok

      {:error, error} ->
        jsv_error = JSV.normalize_error(error)
        case = jsonapi_plug.config[:case]

        {
          :error,
          Enum.flat_map(jsv_error.details, fn detail ->
            Enum.map(detail.errors, fn error ->
              %ErrorObject{
                status: "422",
                title: error.message,
                detail: error.message,
                source: %{pointer: format_pointer(resource, detail.instanceLocation, case)}
              }
            end)
          end)
        }
    end
  end

  defp format_pointer(resource, "#/" <> rest, case),
    do: "/data/attributes/" <> Resource.recase_field(resource, rest, case)

  defp format_pointer(_resource, "#" <> rest, _case), do: "/" <> rest
end
