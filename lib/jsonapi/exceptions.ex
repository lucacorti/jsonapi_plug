defmodule JSONAPI.Exceptions do
  defmodule InvalidQuery do
    @moduledoc """
    Defines a generic exception for when an invalid query is recieved and is unable to be parsed nor handled.
    """
    defexception plug_status: 400,
                 message: "invalid query",
                 type: nil,
                 param: nil,
                 value: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      type = Keyword.fetch!(options, :type)
      value = Keyword.fetch!(options, :value)
      param = Keyword.fetch!(options, :param)

      %__MODULE__{
        message: "invalid parameter #{param}=#{value} for type #{type}",
        type: type,
        param: param,
        value: value
      }
    end
  end

  defmodule InvalidDocument do
    @moduledoc """
    Defines a generic exception for when an invalid document is recieved and is unable to be parsed nor handled.
    """
    defexception plug_status: 400, message: nil, reference: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      message = Keyword.fetch!(options, :message)
      reference = Keyword.fetch!(options, :reference)
      %__MODULE__{message: message, reference: reference}
    end
  end
end
