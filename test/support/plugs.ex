defmodule JSONAPIPlug.TestSupport.Plugs do
  @moduledoc false

  alias JSONAPIPlug.TestSupport.API.{
    DasherizingAPI,
    DefaultAPI,
    OtherHostAPI,
    OtherNamespaceAPI,
    OtherPortAPI,
    OtherSchemeAPI,
    UnderscoringAPI
  }

  alias JSONAPIPlug.TestSupport.Resources.{Car, Post, User}

  defmodule CarResourcePlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, path: "cars", resource: Car
  end

  defmodule UserResourcePlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, path: "users", resource: User
  end

  defmodule PostResourcePlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, path: "posts", resource: Post
  end

  defmodule MyPostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DasherizingAPI, path: "posts", resource: Post
  end

  defmodule OtherNamespacePostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherNamespaceAPI, path: "posts", resource: Post
  end

  defmodule OtherHostPostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherHostAPI, path: "posts", resource: Post
  end

  defmodule OtherPortPostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherPortAPI, path: "posts", resource: Post
  end

  defmodule OtherSchemePostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherSchemeAPI, path: "posts", resource: Post
  end

  defmodule UnderscoringPostPlug do
    @moduledoc false

    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: UnderscoringAPI, path: "posts", resource: Post
  end
end
