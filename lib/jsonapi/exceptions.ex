defmodule JSONAPI.Exceptions do
  defmodule InvalidQuery do
    @moduledoc """
    Defines a generic exception for when an invalid query is recieved and is unable to be parsed nor handled.

    All JSONAPI exceptions on index routes return a 400.
    """
    defexception plug_status: 400,
                 message: "invalid query",
                 resource: nil,
                 param: nil,
                 param_type: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(opts) do
      resource = Keyword.fetch!(opts, :resource)
      param = Keyword.fetch!(opts, :param)
      type = Keyword.fetch!(opts, :param_type)

      %InvalidQuery{
        message: "invalid #{type}, #{param} for type #{resource}",
        resource: resource,
        param: param,
        param_type: type
      }
    end
  end

  @spec raise_invalid_include_query(String.t(), String.t()) :: no_return()
  def raise_invalid_include_query(param, resource_type) do
    raise InvalidQuery, resource: resource_type, param: param, param_type: :include
  end

  @spec raise_invalid_field_names(String.t(), String.t()) :: no_return()
  def raise_invalid_field_names(bad_fields, resource_type) do
    raise InvalidQuery, resource: resource_type, param: bad_fields, param_type: :fields
  end
end
