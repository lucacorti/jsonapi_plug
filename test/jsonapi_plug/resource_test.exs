defmodule JSONAPIPlug.ViewTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.TestSupport.APIs.{
    DasherizingAPI,
    OtherHostAPI,
    OtherNamespaceAPI,
    OtherPortAPI,
    OtherSchemeAPI,
    UnderscoringAPI
  }

  alias JSONAPIPlug.TestSupport.Schemas.{Comment, Post, User}

  alias JSONAPIPlug.TestSupport.Views.{
    CommentView,
    MyPostView,
    PostView,
    UserView
  }

  alias JSONAPIPlug.{Document, Document.ResourceObject, Pagination, View}
  alias Plug.Conn

  defmodule MyPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DasherizingAPI, resource: PostView
  end

  defmodule OtherNamespacePostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherNamespaceAPI, resource: PostView
  end

  defmodule OtherHostPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherHostAPI, resource: PostView
  end

  defmodule OtherPortPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherPortAPI, resource: PostView
  end

  defmodule OtherSchemePostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: OtherSchemeAPI, resource: PostView
  end

  defmodule UnderscoringPostPlug do
    use Plug.Builder

    plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: UnderscoringAPI, resource: PostView
  end

  setup do
    {:ok, conn: conn(:get, "") |> MyPostPlug.call([])}
  end

  test "type/0 when specified via using macro" do
    assert PostView.type() == "post"
  end

  describe "url_for/3 when host and scheme not configured" do
    setup do
      {:ok, conn: conn(:get, "/") |> OtherNamespacePostPlug.call([])}
    end

    test "url_for/3", %{conn: conn} do
      assert View.url_for(PostView, [], conn) == "http://www.example.com/somespace/posts"

      assert View.url_for(PostView, %Post{id: 1}, conn) ==
               "http://www.example.com/somespace/posts/1"

      assert View.url_for(PostView, %{id: 1}, conn) ==
               "http://www.example.com/somespace/posts/1"

      assert View.url_for(
               PostView,
               [],
               %Conn{conn | port: 123}
             ) ==
               "http://www.example.com:123/somespace/posts"

      assert View.url_for_relationship(PostView, [], conn, "comments") ==
               "http://www.example.com/somespace/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, conn, "comments") ==
               "http://www.example.com/somespace/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when host configured" do
    setup do
      {:ok, conn: conn(:get, "/") |> OtherHostPostPlug.call([])}
    end

    test "uses API host instead of that on Conn", %{conn: conn} do
      assert View.url_for_relationship(PostView, [], conn, "comments") ==
               "http://www.otherhost.com/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, conn, "comments") ==
               "http://www.otherhost.com/posts/1/relationships/comments"

      assert View.url_for(PostView, [], conn) == "http://www.otherhost.com/posts"

      assert View.url_for(PostView, %Post{id: 1}, conn) ==
               "http://www.otherhost.com/posts/1"
    end
  end

  describe "url_for/3 when scheme configured" do
    setup do
      {:ok,
       conn:
         conn(:get, "https://www.example.com/")
         |> OtherSchemePostPlug.call([])}
    end

    test "uses API scheme instead of that on Conn", %{conn: conn} do
      assert View.url_for(PostView, [], conn) == "https://www.example.com/posts"

      assert View.url_for(PostView, %Post{id: 1}, conn) ==
               "https://www.example.com/posts/1"

      assert View.url_for_relationship(PostView, [], conn, "comments") ==
               "https://www.example.com/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, conn, "comments") ==
               "https://www.example.com/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when port configured" do
    setup do
      {:ok, conn: conn(:get, "http://www.example.com:42/") |> OtherPortPostPlug.call([])}
    end

    test "uses configured port instead of that on Conn", %{conn: conn} do
      assert View.url_for(PostView, [], conn) == "http://www.example.com:42/posts"

      assert View.url_for(PostView, %{id: 1}, conn) ==
               "http://www.example.com:42/posts/1"

      assert View.url_for_relationship(PostView, [], conn, "comments") ==
               "http://www.example.com:42/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %{id: 1}, conn, "comments") ==
               "http://www.example.com:42/posts/1/relationships/comments"
    end
  end

  describe "url_for_pagination/3" do
    setup do
      {:ok, conn: conn(:get, "https://www.example.com/") |> OtherSchemePostPlug.call([])}
    end

    test "with pagination information", %{conn: conn} do
      assert %URI{path: "/posts"} = Pagination.url_for(PostView, [], conn, %{}) |> URI.parse()

      assert %URI{path: "/posts", query: query} =
               Pagination.url_for(PostView, [], conn, %{number: 1, size: 10}) |> URI.parse()

      assert %{"page[number]" => "1", "page[size]" => "10"} = URI.decode_query(query)
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params = update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert %URI{path: "/posts", query: query} =
               Pagination.url_for(PostView, [], conn_with_query_params, %{
                 number: 1,
                 size: 10
               })
               |> URI.parse()

      assert %{"comments[]" => "2", "page[number]" => "1", "page[size]" => "10"} =
               URI.decode_query(query)
    end
  end

  test "show renders with data, conn" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               attributes: %{
                 "body" => "hi"
               }
             }
           } = View.render(CommentView, conn, %Comment{id: 1, body: "hi"})
  end

  test "show renders with data, conn, meta" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             meta: %{"total_pages" => 100}
           } =
             View.render(CommentView, conn, %Comment{id: 1, body: "hi"}, %{
               "total_pages" => 100
             })
  end

  test "index renders with data, conn" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: [
               %ResourceObject{attributes: %{"body" => "hi"}}
             ]
           } = View.render(CommentView, conn, [%Comment{id: 1, body: "hi"}])
  end

  test "index renders with data, conn, meta" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{meta: %{"total_pages" => 100}} =
             View.render(
               CommentView,
               conn,
               [%Comment{id: 1, body: "hi"}],
               %{"total_pages" => 100}
             )
  end

  test "resource returns all field names by default" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "user",
               attributes:
                 %{
                   "age" => _age,
                   "first_name" => _first_name,
                   "full_name" => _full_name,
                   "last_name" => _last_name,
                   "password" => _password,
                   "username" => _username
                 } = attributes
             }
           } = View.render(UserView, conn, %User{id: 1})

    assert map_size(attributes) == 6
  end

  test "resource trims returned field names to only those requested" do
    conn = conn(:get, "/?fields[#{PostView.type()}]=body") |> MyPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes: %{"body" => _body} = attributes
             }
           } = View.render(PostView, conn, %Post{id: 1, body: "hi", text: "Hello"})

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
             View.render(
               PostView,
               conn,
               %Post{id: 1, body: "Chunky", title: "Bacon", text: "Gello"}
             )

    assert map_size(attributes) == 1
  end

  test "for_related_type/2 using resource.type as key" do
    assert View.for_related_type(MyPostView, "comment") == CommentView
  end

  test "for_type/2 returns nil on invalid fields" do
    assert View.for_related_type(MyPostView, "cupcake") == nil
  end
end
