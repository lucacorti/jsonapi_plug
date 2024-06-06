defmodule JSONAPIPlug.Resource.ErrorFormatter do
  @moduledoc false

  alias ExJsonSchema.Validator.Error
  alias JSONAPIPlug.Document.ErrorObject
  alias JSONAPIPlug.Resource

  def format(errors, resource, case) do
    Enum.flat_map(errors, fn %Error{error: error, path: "#" <> path} ->
      format_error(error, resource, case, "/data/attributes/" <> path)
    end)
  end

  defp format_error(%Error.Required{} = error, resource, case, base_path) do
    Enum.map(error.missing, fn attribute ->
      %ErrorObject{
        title: "Campo obbligatorio",
        detail: "Questo campo è obbligatorio.",
        status: 422,
        code: :unprocessable_entity,
        source: %{pointer: base_path <> Resource.recase_field(resource, attribute, case)}
      }
    end)
  end
end
