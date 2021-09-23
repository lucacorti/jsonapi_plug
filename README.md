# JSON:API library for Plug based applications

Server library to build [JSON:API](http://jsonapi.org) compliant REST APIs.

## JSON:API Support

This library implements [version 1.0](https://jsonapi.org/format/1.0/) of the JSON:API spec.

## Documentation

- [Full docs here](https://hexdocs.pm/jsonapi)
- [JSON API Spec (v1.0)](https://jsonapi.org/format/1.0/)

## Badges

![CI](https://github.com/dottori-it/jsonapi/workflows/Continuous%20Integration/badge.svg)

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

This library can be used with any plug based application and doesn't make use of application configuration.

You can declare an API endpoints by adding the `JSONAPI.Plug` to your plug pipeline or Phoenix Router scope:

```elixir
plug JSONAPI.Plug, api: MyAPI
```

This will take care of ensuring `JSON:API` spec compliance and will return errors for malformed requests.

The `:api` option expects an API module for configuration. You can generate one like this:

```elixir
defmodule MyAPI do
  use JSONAPI.API
end
```

See the `JSONAPI.API` module documentation for available options and callbacks.

### Sending responses

Before serving responses, you need to define your resources.

A resource can be any struct:

```elixir
defmodule MyApp.Post do
  @type t :: %__MODULE__{id: pos_integer(), body: String.t(), title: String.t()}
  defstruct id: nil, body: "", title: ""
end
```

Then define a view module to render your resource:

```elixir
defmodule MyApp.PostView do
  use JSONAPI.View, resource: MyApp.Post

  @impl JSONAPI.View
  def attributes, do: [:title, :text, :excerpt]

  @impl JSONAPI.View
  def meta(%Post{} = post, _conn), do: %{slug: to_slug(post.title)}

  def excerpt(%Post{} = post, _conn), do: String.slice(post.body, 0..5)
end
```

To use the view module as a Phoenix view define your render functions in it:

```elixir
  ...
  
  def render("index.json", %{data: data, conn: conn, meta: meta}) do
    JSONAPI.View.render(__MODULE__, data, conn, meta)
  end

  def render("show.json", %{data: data, conn: conn, meta: meta}) do
    JSONAPI.View.render(__MODULE__, data, conn, meta)
  end

  ...
```

See the `JSONAPI.View` module documentation for usage and available options.

### Receiving requests

In order to parse `JSON:API` requests from clients you need to add the `JSONAPI.Plug.Request` plug
to each of your plug pipelines or phoenix controllers handling requests for a specific resource:

```elixir
plug JSONAPI.Plug.Request, view: PostView
```

You need to provide at least the `:view` option specifying which `JSONAPI.View` will be used.

When requests are processed, the `:jsonapi` connection assign is populated with the parsed request.

See the `JSONAPI.Plug.Request` module documentation for usage and available options.

## Contributing

- This project was born as a fork of [JSONAPI](https://hexdocs.pm/jsonapi)
- The library is maintained by [dottori.it](http://github.com/dottori-it)
- PRs for new features, bug fixes, documentation and tests are welcome
- If you are proposing a large feature, please open an issue for discussion
