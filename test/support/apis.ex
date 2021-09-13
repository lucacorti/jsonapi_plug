defmodule JSONAPI.TestSupport.APIs do
  @moduledoc false

  defmodule DasherizingAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end

  defmodule DefaultAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end

  defmodule OtherHostAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end

  defmodule OtherSchemeAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end

  defmodule OtherNamespaceAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end

  defmodule UnderscoringAPI do
    @moduledoc false
    use JSONAPI.API, otp_app: :jsonapi
  end
end
