defmodule JSONAPI.ViewTest do
  use ExUnit.Case

  alias JSONAPI.TestSupport.APIs.{
    DasherizingAPI,
    DefaultAPI,
    OtherHostAPI,
    OtherNamespaceAPI,
    OtherPortAPI,
    OtherSchemeAPI,
    UnderscoringAPI
  }

  alias JSONAPI.TestSupport.Resources.{Comment, Post, User}
  alias JSONAPI.TestSupport.Views.{CommentView, MyPostView, PostView, UserView}
  alias JSONAPI.{Document, Document.ResourceObject, Pagination, Plug.Request, View}
  alias Plug.Conn

  setup do
    {:ok, conn: Plug.Test.conn(:get, "") |> JSONAPI.Plug.call(api: DasherizingAPI)}
  end

  test "type/0 when specified via using macro" do
    assert PostView.type() == "post"
  end

  describe "url_for/3 when host and scheme not configured" do
    setup do
      {:ok, conn: Plug.Test.conn(:get, "/") |> JSONAPI.Plug.call(api: OtherNamespaceAPI)}
    end

    test "url_for/3", %{conn: conn} do
      assert View.url_for(PostView, nil, conn) == "http://www.example.com/somespace/posts"
      assert View.url_for(PostView, [], conn) == "http://www.example.com/somespace/posts"

      assert View.url_for(PostView, %Post{id: 1}, conn) ==
               "http://www.example.com/somespace/posts/1"

      assert View.url_for(PostView, [], nil) == "/posts"

      assert View.url_for(PostView, nil, nil) == "/posts"
      assert View.url_for(PostView, [], nil) == "/posts"
      assert View.url_for(PostView, %{id: 1}, nil) == "/posts/1"
      assert View.url_for(PostView, [], nil) == "/posts"

      assert View.url_for(
               PostView,
               [],
               %Conn{conn | port: 123}
             ) ==
               "http://www.example.com:123/somespace/posts"

      assert View.url_for(PostView, %{id: 1}, conn) ==
               "http://www.example.com/somespace/posts/1"

      assert View.url_for_relationship(PostView, [], nil, "comments") ==
               "/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, nil, "comments") ==
               "/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when host configured" do
    setup do
      {:ok, conn: Plug.Test.conn(:get, "/") |> JSONAPI.Plug.call(api: OtherHostAPI)}
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
         Plug.Test.conn(:get, "https://www.example.com/")
         |> JSONAPI.Plug.call(api: OtherSchemeAPI)}
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
      {:ok,
       conn:
         Plug.Test.conn(:get, "http://www.example.com:42/")
         |> JSONAPI.Plug.call(api: OtherPortAPI)}
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
      {
        :ok,
        conn:
          Plug.Test.conn(:get, "https://www.example.com/")
          |> JSONAPI.Plug.call(api: OtherSchemeAPI)
          |> Conn.fetch_query_params()
      }
    end

    test "with pagination information", %{conn: conn} do
      assert Pagination.url_for(PostView, nil, conn, %{}) ==
               "https://www.example.com/posts"

      assert Pagination.url_for(PostView, nil, conn, %{number: 1, size: 10}) ==
               "https://www.example.com/posts?page%5Bnumber%5D=1&page%5Bsize%5D=10"
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params = update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert Pagination.url_for(PostView, nil, conn_with_query_params, %{
               number: 1,
               size: 10
             }) ==
               "https://www.example.com/posts?comments%5B%5D=5&comments%5B%5D=2&page%5Bnumber%5D=1&page%5Bsize%5D=10"

      assert Pagination.url_for(PostView, nil, conn_with_query_params, %{}) ==
               "https://www.example.com/posts?comments%5B%5D=5&comments%5B%5D=2"
    end
  end

  test "show renders with data, conn" do
    assert %Document{
             data: %ResourceObject{
               attributes: %{
                 "body" => "hi"
               }
             }
           } = View.render(CommentView, nil, %Comment{id: 1, body: "hi"})
  end

  test "show renders with data, conn, meta" do
    assert %Document{
             meta: %{total_pages: 100}
           } = View.render(CommentView, nil, %Comment{id: 1, body: "hi"}, %{total_pages: 100})
  end

  test "index renders with data, conn" do
    assert %Document{
             data: [
               %ResourceObject{attributes: %{"body" => "hi"}}
             ]
           } = View.render(CommentView, nil, [%Comment{id: 1, body: "hi"}])
  end

  test "index renders with data, conn, meta" do
    assert %Document{meta: %{total_pages: 100}} =
             View.render(
               CommentView,
               nil,
               [%Comment{id: 1, body: "hi"}],
               %{total_pages: 100}
             )
  end

  test "view returns all field names by default" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Parsers.call(
        Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)
      )
      |> JSONAPI.Plug.call(api: UnderscoringAPI)
      |> Request.call(view: UserView)

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

  test "view trims returned field names to only those requested" do
    conn =
      Plug.Test.conn(:get, "/?fields[#{PostView.type()}]=body")
      |> Plug.Parsers.call(
        Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)
      )
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(view: PostView)

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
    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes: %{"body" => "Chunky"} = attributes
             }
           } =
             View.render(
               PostView,
               %Conn{private: %{jsonapi: %JSONAPI{fields: %{PostView.type() => [:body]}}}},
               %Post{id: 1, body: "Chunky", title: "Bacon", text: "Gello"}
             )

    assert map_size(attributes) == 1
  end

  test "for_related_type/2 using view.type as key" do
    assert View.for_related_type(MyPostView, "comment") == CommentView
  end

  test "for_type/2 returns nil on invalid fields" do
    assert View.for_related_type(MyPostView, "cupcake") == nil
  end
end
