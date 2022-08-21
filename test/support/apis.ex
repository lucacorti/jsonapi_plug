defmodule JSONAPIPlug.TestSupport.APIs do
  @moduledoc false

  defmodule DasherizingAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule DefaultAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule OtherHostAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule OtherSchemeAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule OtherNamespaceAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule OtherPortAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule UnderscoringAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end
end
