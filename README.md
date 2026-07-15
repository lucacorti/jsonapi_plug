# JSON:API library for Plug and Phoenix applications

Server library to build [JSON:API](http://jsonapi.org) compliant REST APIs.

## JSON:API Support

This library currently implements version `1.0` of the [JSON:API][json:api] specification.
However, to support resource creation alongside included resources, `JSON:API 1.1` `lid` is supported.

## Documentation

- Full documentation can be found on [hexdocs.pm][jsonapi_plug-hexdocs]

For the `JSON:API` specification documentation as well as other client and server implementations:

- [JSON:API][json:api]
- [JSON:API Specification (v1.0)][json:api-1.0]
- [JSON:API Specification (v1.1)][json:api-1.1]

## Quickstart

### Installation

Add the following line to your `mix.deps` file with the desired version to install `jsonapi_plug`.

```elixir
defp deps do [
  ...
  {:jsonapi_plug, "~> 2.0"}
  ...
]
```

### Upgrading

Upgrading the library should be safe for minor and patch version upgrades, it's still a good practice
to check the [changelog][changelog] for more information on the release content. For major version
upgrades, breaking changes should be expected, and the [upgrade guide][upgrade] contains instructions
on upgrading between major releases of the library.

### Configuration

You start by declaring one or more APIs. APIs are collections of endpoints that
share a common configuration:

```elixir
defmodule MyApp.API do
  use JSONAPIPlug.API, otp_app: :my_app
end
```

See the `JSONAPIPlug.API` module documentation to learn how to customize your APIs
via application configuration of your app.

### Resources

To start accept requests and serving responses, you need to define `JSON:API` resources.
Resources can be any struct `@derive`-ing the `JSONAPIPlug.Resource` protocol:

```elixir
defmodule MyApp.Post do
  use Ecto.Schema

  @type t :: %__MODULE__{id: pos_integer(), body: String.t(), title: String.t()}

  @derive {
    JSONAPIPlug.Resource,
    type: "post",
    attributes: [:title, :text, :excerpt]
  }
  schema "posts" do
    field :title
    field :text
  end

  ...
end
```

See `JSONAPIPlug.Resource` for the complete documentation of options you can pass to `@derive`,
including how to control serialization and deserialization, and add related resources.

Also, three optional protocols are available to allow further customization of resources.

- Resource attribute custom serialization and deserialization: `JSONAPIPlug.Resource.Attribute`
- Resource link generation: `JSONAPIPlug.Resource.Links`
- Resource link generation: `JSONAPIPlug.Resource.Meta`

### Usage with Phoenix

To serve JSON:API resources in Phoenix, you need to define routes in your router:

```elixir
defmodule MyAppWeb.Router do
  ...
  resource "/posts", MyApp.PostsController, only: [:create, :index, :show]
  patch "/posts/:id", MyApp.PostsController, :update
end
```

In order to parse `JSON:API` requests from clients you need to add the `JSONAPIPlug.Plug` plug to each of your
phoenix controllers handling requests for a specific resource. This will take care of ensuring `JSON:API` request
compliance and will return errors for malformed requests.

When a valid request processed, the `:jsonapi_plug` `Plug.Conn` private field will be populated in the controller.

You can learn all about advanced request handling, including custom filtering, relationships inclusion, pagination
and sparse fields support by reading the `JSONAPIPlug.Plug` module documentation.

Once you receive a request in your controller and load data, you just call render to send a response:

```elixir
  defmodule MyAppWeb.PostsController do
    ...
    plug JSONAPIPlug.Plug, api: MyApp.API, path: "posts", resource: MyApp.Post
    ...

    def create(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, params) do
      post = ...create a post using jsonapi_plug parsed parameters...
      render(conn, "create.json", %{data: post})
    end

    def index(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, _params) do
      posts = ...load data using jsonapi_plug parsed parameters...
      render(conn, "index.json", %{data: post})
    end

    def show(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, _params) do
      post = ...load data using jsonapi_plug parsed parameters...
      render(conn, "show.json", %{data: post})
    end

    def update(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, params) do
      post = ...update a post using jsonapi_plug parsed parameters...
      render(conn, "update.json", %{data: post})
    end
  end
```

For phoenix to dispatch this for rendering you need to add this code to your `MyAppWeb` module:

```elixir
def MyAppWeb do
 ...

  def json_api do
    quote do
      use JSONAPIPlug.Phoenix.Component
    end
  end

...
end
```

and define a corresponding rendering template module:

```elixir
defmodule SibillWeb.PostsJSON do
  @moduledoc false

  use MyAppWeb, :json_api
end
```

alternatively you can skip these steps by calling `JSONAPIPlug.render/4` directly instead of `render/3` in you controller:

```elixir
...
    def show(%Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} = conn, _params) do
      post = ...load data using jsonapi_plug parsed parameters...
      JSONAPIPlug.render(conn, post \\ nil, meta \\ nil, options \\ [])
    end
...
```

### Usage with Plug

If you have a `Plug` application, assuming you already set up routing you can call `JSONAPIPlug.render/4` in your
pipeline to generate a `JSONAPI.Document` with your data for the client.

```elixir
JSONAPIPlug.render(conn, post)
|> Jason.encode!()
```

Render returns a `JSONAPI.Document`, that is serializable to JSON via `Jason`.

## Contributing

- This project was born as a fork of the [jsonapi][jsonapi-fork]
library but has since been completely rewritten and is now a completely different project.
- PRs for new features, bug fixes, documentation and tests are welcome
- If you are proposing a large feature or change, please open an issue for discussion

[changelog]: https://hexdocs.pm/jsonapi_plug/changelog.html
[json:api-1.0]: https://jsonapi.org/format/1.0/
[json:api-1.1]: https://jsonapi.org/format/1.1/
[json:api]: https://jsonapi.org
[jsonapi-fork]: https://github.com/beam-community/jsonapi
[jsonapi_plug-hexdocs]: https://hexdocs.pm/jsonapi_plug
[upgrade]: https://hexdocs.pm/jsonapi_plug/upgrading.html
