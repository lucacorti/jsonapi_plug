defmodule JSONAPI.Exceptions do
  defmodule InvalidQuery do
    @moduledoc """
    Defines a generic exception for when an invalid query is recieved and is unable to be parsed nor handled.

    All JSONAPI exceptions on index routes return a 400.
    """
    defexception plug_status: 400,
                 message: "invalid query",
                 type: nil,
                 param: nil,
                 value: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(opts) do
      type = Keyword.fetch!(opts, :type)
      value = Keyword.fetch!(opts, :value)
      param = Keyword.fetch!(opts, :param)

      %InvalidQuery{
        message: "invalid parameter #{param}=#{value} for type #{type}",
        type: type,
        param: param,
        value: value
      }
    end
  end
end
