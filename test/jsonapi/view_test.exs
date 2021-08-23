defmodule JSONAPI.ViewTest do
  use ExUnit.Case

  alias JSONAPI.TestSupport.Resources.{Comment, Post, User}
  alias JSONAPI.TestSupport.Views.{CarView, CommentView, MyPostView, PostView, UserView}
  alias JSONAPI.{Document, Document.ResourceObject, Paginator, View}
  alias Plug.Conn

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)
    Application.put_env(:jsonapi, :namespace, "/other-api")

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
      Application.delete_env(:jsonapi, :namespace)
    end)

    {:ok, []}
  end

  test "type/0 when specified via using macro" do
    assert PostView.type() == "post"
  end

  describe "namespace/0" do
    setup do
      Application.put_env(:jsonapi, :namespace, "/cake")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :namespace)
      end)

      {:ok, []}
    end

    test "uses macro configuration first" do
      assert PostView.__namespace__() == nil
    end

    test "uses global namespace if available" do
      assert UserView.__namespace__() == "cake"
    end

    test "namespace cant be blank" do
      assert CarView.__namespace__() == nil
    end
  end

  describe "url_for/3 when host and scheme not configured" do
    test "url_for/3" do
      assert View.url_for(PostView, nil, nil) == "/other-api/posts"
      assert View.url_for(PostView, [], nil) == "/other-api/posts"
      assert View.url_for(PostView, %Post{id: 1}, nil) == "/other-api/posts/1"
      assert View.url_for(PostView, [], %Conn{}) == "http://www.example.com/other-api/posts"

      assert View.url_for(PostView, %Post{id: 1}, %Conn{}) ==
               "http://www.example.com/other-api/posts/1"

      assert View.url_for_relationship(PostView, [], %Conn{}, "comments") ==
               "http://www.example.com/other-api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, %Conn{}, "comments") ==
               "http://www.example.com/other-api/posts/1/relationships/comments"
    end
  end

  describe "url_for/3 when host configured" do
    setup do
      Application.put_env(:jsonapi, :host, "www.otherhost.com")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :host)
      end)

      {:ok, []}
    end

    test "uses configured host instead of that on Conn" do
      assert View.url_for_relationship(PostView, [], %Conn{}, "comments") ==
               "http://www.otherhost.com/other-api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, %Conn{}, "comments") ==
               "http://www.otherhost.com/other-api/posts/1/relationships/comments"

      assert View.url_for(PostView, [], %Conn{}) == "http://www.otherhost.com/other-api/posts"

      assert View.url_for(PostView, %Post{id: 1}, %Conn{}) ==
               "http://www.otherhost.com/other-api/posts/1"
    end
  end

  describe "url_for/3 when scheme configured" do
    setup do
      Application.put_env(:jsonapi, :scheme, "ftp")

      on_exit(fn -> Application.delete_env(:jsonapi, :scheme) end)

      {:ok, []}
    end

    test "uses configured scheme instead of that on Conn" do
      assert View.url_for(PostView, [], %Conn{}) == "ftp://www.example.com/other-api/posts"

      assert View.url_for(PostView, %Post{id: 1}, %Conn{}) ==
               "ftp://www.example.com/other-api/posts/1"

      assert View.url_for_relationship(PostView, [], %Conn{}, "comments") ==
               "ftp://www.example.com/other-api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, %Conn{}, "comments") ==
               "ftp://www.example.com/other-api/posts/1/relationships/comments"
    end
  end

  describe "url_for/3" do
    setup do
      {:ok, conn: Conn.fetch_query_params(%Conn{})}
    end

    test "with pagination information", %{conn: conn} do
      assert Paginator.url_for(PostView, nil, conn, %{}) ==
               "http://www.example.com/other-api/posts"

      assert Paginator.url_for(PostView, nil, conn, %{number: 1, size: 10}) ==
               "http://www.example.com/other-api/posts?page%5Bnumber%5D=1&page%5Bsize%5D=10"
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params =
        Kernel.update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert Paginator.url_for(PostView, nil, conn_with_query_params, %{
               number: 1,
               size: 10
             }) ==
               "http://www.example.com/other-api/posts?comments%5B%5D=5&comments%5B%5D=2&page%5Bnumber%5D=1&page%5Bsize%5D=10"

      assert Paginator.url_for(PostView, nil, conn_with_query_params, %{}) ==
               "http://www.example.com/other-api/posts?comments%5B%5D=5&comments%5B%5D=2"
    end
  end

  test "render/2 is defined when 'Phoenix' is loaded" do
    assert {:render, 2} in CommentView.__info__(:functions)
  end

  test "show renders with data, conn" do
    %Document{
      data: %ResourceObject{
        attributes: %{
          body: "hi"
        }
      }
    } = CommentView.render("show.json", %{data: %Comment{id: 1, body: "hi"}, conn: %Conn{}})
  end

  test "show renders with data, conn, meta" do
    %Document{
      meta: %{total_pages: 100}
    } =
      CommentView.render("show.json", %{
        data: %Comment{id: 1, body: "hi"},
        conn: %Conn{},
        meta: %{total_pages: 100}
      })
  end

  test "index renders with data, conn" do
    assert %Document{
             data: [
               %ResourceObject{attributes: %{body: "hi"}} | _
             ]
           } =
             CommentView.render("index.json", %{
               data: [%Comment{id: 1, body: "hi"}],
               conn: Conn.fetch_query_params(%Conn{})
             })
  end

  test "index renders with data, conn, meta" do
    assert %Document{meta: %{total_pages: 100}} =
             CommentView.render("index.json", %{
               data: [%Comment{id: 1, body: "hi"}],
               conn: Conn.fetch_query_params(%Conn{}),
               meta: %{total_pages: 100}
             })
  end

  test "view returns all field names by default" do
    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "user",
               attributes:
                 %{
                   age: _age,
                   first_name: _first_name,
                   last_name: _last_name,
                   full_name: _full_name,
                   username: _username,
                   password: _password
                 } = attributes
             }
           } =
             UserView.render("show.json", %{
               data: %User{id: 1},
               conn: Conn.fetch_query_params(%Conn{})
             })

    assert 6 = map_size(attributes)
  end

  test "view trims returned field names to only those requested" do
    conn =
      Conn.fetch_query_params(%Conn{
        assigns: %{jsonapi: %JSONAPI{fields: %{PostView.type() => [:body]}}}
      })

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes:
                 %{
                   body: _body
                 } = attributes
             }
           } = PostView.render("show.json", %{data: %Post{id: 1, body: "hi"}, conn: conn})

    assert 1 = map_size(attributes)
  end

  test "attributes/2 can return only requested fields" do
    conn =
      Conn.fetch_query_params(%Conn{
        assigns: %{jsonapi: %JSONAPI{fields: %{PostView.type() => [:body]}}}
      })

    assert %Document{
             data: %ResourceObject{
               id: "1",
               type: "post",
               attributes:
                 %{
                   body: _body
                 } = attributes
             }
           } =
             PostView.render("show.json", %{
               data: %Post{id: 1, body: "Chunky", title: "Bacon"},
               conn: conn
             })

    assert 1 = map_size(attributes)
  end

  test "for_related_type/2 using view.type as key" do
    assert View.for_related_type(MyPostView, "comment") == CommentView
  end

  test "for_type/2 returns nil on invalid fields" do
    assert View.for_related_type(MyPostView, "cupcake") == nil
  end
end
