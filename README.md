# JSON:API library for Plug based applications

Server library to build [JSON:API](http://jsonapi.org) compliant REST APIs.

## JSON:API Support

This library implements [version 1.0](https://jsonapi.org/format/1.0/) of the JSON:API spec.

## Documentation

- [Full docs here](https://hexdocs.pm/jsonapi)
- [JSON API Spec (v1.0)](https://jsonapi.org/format/1.0/)

## Badges

![CI](https://github.com/lucacorti/jsonapi/workflows/Continuous%20Integration/badge.svg)

## Quickstart

### Installation

Add the following line to your `mix.deps` file with the desired version to install `jsonapi`.

```elixir
defp deps do [
  ...
  {:jsonapi, "~> 1.0"}
  ...
]
```

### Configuration

This library can be used with any plug based application and doesn't make use of global configuration.

You can declare an API endpoints by adding the `JSONAPI.Plug` to your plug pipeline or Phoenix Router:

```elixir
plug JSONAPI.Plug, api: MyApp.MyAPI
```

This will take care of ensuring `JSON:API` spec compliance and will return errors for malformed requests.
The `:api` option expects an API module for configuration. You can generate one like this:

```elixir
defmodule MyApp.MyAPI do
  use JSONAPI.API, otp_app: :my_app
end
```

See the `JSONAPI.API` module documentation to learn how to configure your APIs via application configuration.

### Sending responses

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
  use JSONAPI.View,
    type: "post"
    attributes: [
      title: nil,
      text: nil,
      excerpt: [serialize: fn %Post{} = post, _conn), do: String.slice(post.body, 0..5) end]
    ]

  @impl JSONAPI.View
  def meta(%Post{} = post, _conn), do: %{slug: to_slug(post.title)}
end
```

To use the view module in Phoenix, just call render and pass the data from your controller:

```elixir
  defmodule MyAppWeb.PostsController do
    
    def show(_conn, _params) do
      user = %MyApp.Post{id: 1, title: "A thrilling post", body: "Some interesting content..."}
      conn
      |> put_view(MyApp.UsersView)
      |> render("show.json", %{data: data})
    end

  end
```

See the `JSONAPI.View` module documentation for usage and options.

### Receiving requests

In order to parse `JSON:API` requests from clients you need to add the `JSONAPI.Plug.Request` plug
to each of your plug pipelines or phoenix controllers handling requests for a specific resource:

```elixir
defmodule MyApp.PostsController do
  ...
  plug JSONAPI.Plug.Request, view: MyApp.PostsView
  ...
end
```

You need to provide at least the `:view` option specifying which `JSONAPI.View`to use for your controller.

When requests are processed, the `:jsonapi` connection private field is populated with the parsed request.

See the `JSONAPI.Plug.Request` module documentation for usage and options.

## Contributing

- This project was born as a fork of [JSONAPI](https://hexdocs.pm/jsonapi)
- PRs for new features, bug fixes, documentation and tests are welcome
- If you are proposing a large feature, please open an issue for discussion
