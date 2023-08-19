defmodule JSONAPIPlug.ResourceTest do
  use ExUnit.Case
  use Plug.Test

  import JSONAPIPlug.Resource, only: [recase: 2]

  doctest JSONAPIPlug.Resource

  alias JSONAPIPlug.TestSupport.APIs.{
    DasherizingAPI,
    OtherHostAPI,
    OtherNamespaceAPI,
    OtherPortAPI,
    OtherSchemeAPI,
    UnderscoringAPI
  }

  alias JSONAPIPlug.TestSupport.Resources.{Comment, Post, User}

  alias JSONAPIPlug.{Document, Document.ResourceObject, Resource}

  defmodule PostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DasherizingAPI, resource: Post
  end

  defmodule OtherNamespacePostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherNamespaceAPI, resource: Post
  end

  defmodule OtherHostPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherHostAPI, resource: Post
  end

  defmodule OtherPortPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherPortAPI, resource: Post
  end

  defmodule OtherSchemePostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherSchemeAPI, resource: Post
  end

  defmodule UnderscoringPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: UnderscoringAPI, resource: Post
  end

  setup do
    {:ok, conn: conn(:get, "") |> PostPlug.call([])}
  end

  test "show renders with data, conn" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               attributes: %{
                 "body" => "hi"
               }
             }
           } = Resource.render(conn, %Comment{id: 1, body: "hi"})
  end

  test "index renders with data, conn" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: [
               %ResourceObject{attributes: %{"body" => "hi"}}
             ]
           } = Resource.render(conn, [%Comment{id: 1, body: "hi"}])
  end

  test "resource returns all field names by default" do
    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "user",
               attributes:
                 %{
                   "age" => _age,
                   "firstName" => _first_name,
                   "fullName" => _full_name,
                   "lastName" => _last_name,
                   "password" => _password,
                   "username" => _username
                 } = attributes
             }
           } =
             conn(:get, "/")
             |> UnderscoringPostPlug.call([])
             |> Resource.render(%User{id: 1})

    assert map_size(attributes) == 6
  end

  test "resource trims returned field names to only those requested" do
    conn = conn(:get, "/?fields[post]=body") |> PostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes: %{"body" => _body} = attributes
             }
           } = Resource.render(conn, %Post{id: 1, body: "hi", text: "Hello"})

    assert map_size(attributes) == 1
  end

  test "attributes/2 can return only requested fields" do
    conn = conn(:get, "/?fields[post]=body") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes: %{"body" => "Chunky"} = attributes
             }
           } =
             Resource.render(
               conn,
               %Post{id: 1, body: "Chunky", title: "Bacon", text: "Gello"}
             )

    assert map_size(attributes) == 1
  end
end
