defmodule JSONAPIPlug.ResourceTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.TestSupport.Plugs.{
    MyPostPlug,
    OtherHostPostPlug,
    OtherNamespacePostPlug,
    OtherPortPostPlug,
    OtherSchemePostPlug,
    UnderscoringPostPlug
  }

  alias JSONAPIPlug.TestSupport.Resources.{Comment, Post, User}
  alias JSONAPIPlug.{Document, Document.ResourceObject, Pagination, Resource}

  setup do
    {:ok, conn: conn(:get, "/") |> MyPostPlug.call([])}
  end

  test "type/0 when specified via using macro" do
    assert Resource.type(%Post{}) == "post"
  end

  describe "url_for/3 when host and scheme not configured" do
    setup do
      {:ok, conn: conn(:get, "/") |> OtherNamespacePostPlug.call([])}
    end

    test "url_for/3", %{conn: conn} do
      assert JSONAPIPlug.url_for([%Post{}], conn) ==
               "http://www.example.com/somespace/posts"

      assert JSONAPIPlug.url_for(%Post{id: 1}, conn) ==
               "http://www.example.com/somespace/posts/1"

      assert JSONAPIPlug.url_for_relationship([], conn, "comments") ==
               "http://www.example.com/somespace/posts/relationships/comments"

      assert JSONAPIPlug.url_for_relationship(%Post{id: 1}, conn, "comments") ==
               "http://www.example.com/somespace/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when host configured" do
    setup do
      {:ok, conn: conn(:get, "/") |> OtherHostPostPlug.call([])}
    end

    test "uses API host instead of that on Conn", %{conn: conn} do
      assert JSONAPIPlug.url_for_relationship([], conn, "comments") ==
               "http://www.otherhost.com/posts/relationships/comments"

      assert JSONAPIPlug.url_for_relationship(%Post{id: 1}, conn, "comments") ==
               "http://www.otherhost.com/posts/1/relationships/comments"

      assert JSONAPIPlug.url_for([], conn) == "http://www.otherhost.com/posts"

      assert JSONAPIPlug.url_for(%Post{id: 1}, conn) ==
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
      assert JSONAPIPlug.url_for([], conn) == "https://www.example.com/posts"

      assert JSONAPIPlug.url_for(%Post{id: 1}, conn) ==
               "https://www.example.com/posts/1"

      assert JSONAPIPlug.url_for_relationship([], conn, "comments") ==
               "https://www.example.com/posts/relationships/comments"

      assert JSONAPIPlug.url_for_relationship(%Post{id: 1}, conn, "comments") ==
               "https://www.example.com/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when port configured" do
    setup do
      {:ok, conn: conn(:get, "http://www.example.com:42/") |> OtherPortPostPlug.call([])}
    end

    test "uses configured port instead of that on Conn", %{conn: conn} do
      assert JSONAPIPlug.url_for([], conn) == "http://www.example.com:42/posts"

      assert JSONAPIPlug.url_for(%Post{id: 1}, conn) ==
               "http://www.example.com:42/posts/1"

      assert JSONAPIPlug.url_for_relationship([], conn, "comments") ==
               "http://www.example.com:42/posts/relationships/comments"

      assert JSONAPIPlug.url_for_relationship(%Post{id: 1}, conn, "comments") ==
               "http://www.example.com:42/posts/1/relationships/comments"
    end
  end

  describe "url_for_pagination/3" do
    setup do
      {:ok, conn: conn(:get, "https://www.example.com/") |> OtherSchemePostPlug.call([])}
    end

    test "with pagination information", %{conn: conn} do
      assert %URI{path: "/posts"} = Pagination.url_for([], conn, %{}) |> URI.parse()

      assert %URI{path: "/posts", query: query} =
               Pagination.url_for([], conn, %{number: 1, size: 10}) |> URI.parse()

      assert %{"page[number]" => "1", "page[size]" => "10"} = URI.decode_query(query)
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params = update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert %URI{path: "/posts", query: query} =
               Pagination.url_for([], conn_with_query_params, %{
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
           } = JSONAPIPlug.render(conn, %Comment{id: 1, body: "hi"})
  end

  test "show renders with data, conn, meta" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             meta: %{"total_pages" => 100}
           } =
             JSONAPIPlug.render(conn, %Comment{id: 1, body: "hi"}, %{
               "total_pages" => 100
             })
  end

  test "index renders with data, conn" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{
             data: [
               %ResourceObject{attributes: %{"body" => "hi"}}
             ]
           } = JSONAPIPlug.render(conn, [%Comment{id: 1, body: "hi"}])
  end

  test "index renders with data, conn, meta" do
    conn = conn(:get, "/") |> UnderscoringPostPlug.call([])

    assert %Document{meta: %{"total_pages" => 100}} =
             JSONAPIPlug.render(
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
           } = JSONAPIPlug.render(conn, %User{id: 1})

    assert map_size(attributes) == 6
  end

  test "resource trims returned field names to only those requested" do
    conn = conn(:get, "/?fields[#{Resource.type(%Post{})}]=body") |> MyPostPlug.call([])

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes: %{"body" => _body} = attributes
             }
           } = JSONAPIPlug.render(conn, %Post{id: 1, body: "hi", text: "Hello"})

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
             JSONAPIPlug.render(
               conn,
               %Post{id: 1, body: "Chunky", title: "Bacon", text: "Gello"}
             )

    assert map_size(attributes) == 1
  end
end
