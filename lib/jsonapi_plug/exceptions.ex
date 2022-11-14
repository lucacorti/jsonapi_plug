defmodule JSONAPIPlug.Exceptions do
  @moduledoc false

  defmodule InvalidDocument do
    @moduledoc """
    Defines a generic exception for when an invalid document is received.
    """
    defexception message: nil, reference: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      message = Keyword.fetch!(options, :message)
      reference = Keyword.fetch!(options, :reference)

      %__MODULE__{message: message, reference: reference}
    end
  end

  defmodule InvalidHeader do
    @moduledoc """
    Defines a generic exception for when an invalid header is received.
    """
    defexception header: nil, message: nil, reference: nil, status: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      header = Keyword.fetch!(options, :header)
      message = Keyword.fetch!(options, :message)
      reference = Keyword.fetch!(options, :reference)
      status = Keyword.fetch!(options, :status)

      %__MODULE__{header: header, message: message, reference: reference, status: status}
    end
  end

  defmodule InvalidQuery do
    @moduledoc """
    Defines a generic exception for when an invalid query parameter is received.
    """
    defexception message: "invalid query",
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
end
