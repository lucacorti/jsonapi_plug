defprotocol JSONAPIPlug.Resource.Validator do
  @moduledoc """
  Resource Validator

  Implement this protocol to validate a JSON:API resource.
  Validation will be performed on resource attributes before normalizig them.

  This example implementation always accepts params regardless of what is received.

  ```elixir
    defimpl JSONAPIPlug.Resource.Meta, for: MyApp.Post do
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
  """
  @spec validate(Resource.t(), ResourceObject.attributes(), Conn.t()) ::
          :ok | {:error, [ErrorObject.t()]}
  def validate(resource, attributes, conn)
end

defimpl JSONAPIPlug.Resource.Validator, for: Any do
  alias ExJsonSchema.Validator
  alias JSONAPIPlug.Resource
  alias JSONAPIPlug.Resource.Validator.ErrorFormatter
  alias Plug.Conn

  def validate(_resource, _attributes, %Conn{method: "PATCH"}), do: :ok

  def validate(resource, attributes, %Conn{
        private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}
      }) do
    case Validator.validate(Resource.schema(resource), attributes, error_formatter: false) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error, ErrorFormatter.format(errors, resource, jsonapi_plug.config[:case])}
    end
  end
end
