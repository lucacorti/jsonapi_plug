defmodule JSONAPI.TestSupport.APIs do
  @moduledoc false

  alias JSONAPI.TestSupport.Paginators.PageBasedPaginator

  defmodule DasherizingAPI do
    @moduledoc false
    use JSONAPI.API, inflection: :dasherize
  end

  defmodule DefaultAPI do
    @moduledoc false
    use JSONAPI.API, paginator: PageBasedPaginator
  end

  defmodule OtherHostAPI do
    @moduledoc false
    use JSONAPI.API, host: "www.otherhost.com"
  end

  defmodule OtherSchemeAPI do
    @moduledoc false
    use JSONAPI.API, scheme: :https
  end

  defmodule OtherNamespaceAPI do
    @moduledoc false
    use JSONAPI.API, namespace: "somespace"
  end

  defmodule UnderscoringAPI do
    @moduledoc false
    use JSONAPI.API, inflection: :underscore
  end
end
