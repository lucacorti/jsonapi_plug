defmodule JSONAPIPlug.Exceptions do
  @moduledoc false

  defmodule InvalidDocument do
    @moduledoc """
    Exception for when an invalid document is received.
    """
    alias JSONAPIPlug.Document.ErrorObject
    defexception message: nil, errors: nil

    @default_error %ErrorObject{
      status: "500",
      title: "An error occurred while processing the request.",
      detail: "Contact the system administrator for assitance."
    }

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      message = List.first(options[:errors], @default_error).title

      %__MODULE__{message: message, errors: options[:errors] || [@default_error]}
    end
  end

  defmodule InvalidAttributes do
    @moduledoc """
    Exception for when invalid resource attributes are received.
    """
    defexception message: nil, errors: nil

    @spec exception(keyword()) :: Exception.t()
    def exception(options) do
      %__MODULE__{message: options[:message], errors: options[:errors]}
    end
  end

  defmodule InvalidHeader do
    @moduledoc """
    Exception for when an invalid header is received.
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
    Exception for when an invalid query parameter is received.
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
