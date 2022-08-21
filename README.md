# JSON:API library for Phoenix and Plug applications

Server library to build [JSON:API](http://jsonapi.org) compliant REST APIs.

## JSON:API Support

This library currently implements [version 1.0](https://jsonapi.org/format/1.0/) of the JSON:API spec.

## Documentation

- [Full docs here](https://hexdocs.pm/jsonapi_plug)
- [JSON API Spec (v1.0)](https://jsonapi.org/format/1.0/)

## Badges

![CI](https://github.com/lucacorti/jsonapi_plug/workflows/Continuous%20Integration/badge.svg)

## Quickstart

### Installation

Add the following line to your `mix.deps` file with the desired version to install `jsonapi_plug`.

```elixir
defp deps do [
  ...
  {:jsonapi_plug, "~> 1.0"}
  ...
]
```

### Configuration

This library can be used with any plug based application and doesn't make use of global configuration.

You start by declaring one or more APIs. APIs are collections of endpoints that
share a common configuration:

```elixir
defmodule MyApp.API do
  use JSONAPIPlug.API, otp_app: :my_app
end
```

See the `JSONAPIPlug.API` module documentation to learn how to customize your APIs
via application configuration of your app.

### Receiving requests

In order to parse `JSON:API` requests from clients you need to add the `JSONAPIPlug.Plug` plug to each of your plug pipelines or phoenix controllers handling requests for a specific resource:

```elixir
defmodule MyApp.PostsController do
  ...
  plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.PostsView
  ...
end
```

This will take care of ensuring `JSON:API` spec compliance and will return errors for malformed requests.

The `:api` option expects an API module for configuration.

You also need to provide the `:view` option specifying which `JSONAPIPlug.View` to use for rendering data provided by your controller.

When requests are processed, the `:jsonapi_plug` connection private field is populated with the parsed request.

See the `JSONAPIPlug.Plug` module documentation for usage and options.

### Serving responses

To start serving responses, you need to have some data to return to clients:

```elixir
defmodule MyApp.Post do
  @type t :: %__MODULE__{id: pos_integer(), body: String.t(), title: String.t()}

  @enforce_keys [:id, :body, :title]
  defstruct id: nil, body: "", title: ""
end
```

and define a view module to render your resource:

```elixir
defmodule MyApp.PostsView do
  use JSONAPIPlug.View,
    type: "post"
    attributes: [
      title: nil,
      text: nil,
      excerpt: [serialize: fn %Post{} = post, _conn -> String.slice(post.body, 0..5) end]
    ]

  @impl JSONAPIPlug.View
  def meta(%Post{} = post, _conn), do: %{slug: to_slug(post.title)}
end
```

To use the view module in Phoenix, just call render and pass the data from your controller:

```elixir
  defmodule MyAppWeb.PostsController do
    ...
    plug JSONAPIPlug.Plug, api: MyApp.API, view: MyApp.PostsView
    ...

    def show(_conn, _params) do
      user = %MyApp.Post{id: 1, title: "A thrilling post", body: "Some interesting content..."}
      conn
      |> put_view(MyApp.UsersView)
      |> render("show.json", %{data: data})
    end

  end
```

See the `JSONAPIPlug.View` module documentation for usage and options.

## Contributing

- This project was born as a fork of [JSONAPI](https://hexdocs.pm/jsonapi_plug) but was almost completely rewritten and is now a different project, therefore the APIs are not compatible.
- PRs for new features, bug fixes, documentation and tests are welcome
- If you are proposing a large feature, please open an issue for discussion
