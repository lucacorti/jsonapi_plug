defmodule JSONAPI.ViewTest do
  use ExUnit.Case

  alias JSONAPI.SupportTest.{Comment, Post, User}
  alias JSONAPI.View

  defmodule PostView do
    use JSONAPI.View, resource: Post, type: "post", path: "posts", namespace: "/api"

    @impl JSONAPI.View
    def fields, do: [:title, :body]
  end

  defmodule CommentView do
    use JSONAPI.View, resource: Comment, type: "comment", path: "comments", namespace: "/api"

    @impl JSONAPI.View
    def fields, do: [:body]
  end

  defmodule UserView do
    use JSONAPI.View, resource: User, type: "user", path: "users"

    @impl JSONAPI.View
    def fields, do: [:age, :first_name, :last_name, :full_name, :password]

    def full_name(user, _conn) do
      "#{user.first_name} #{user.last_name}"
    end
  end

  defmodule CarView do
    use JSONAPI.View, resource: Car, type: "cars", namespace: ""
  end

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
      assert PostView.namespace() == "/api"
    end

    test "uses global namespace if available" do
      assert UserView.namespace() == "/cake"
    end

    test "can be blank" do
      assert CarView.namespace() == ""
    end
  end

  describe "url_for/2 when host and scheme not configured" do
    test "url_for/2" do
      assert PostView.url_for(nil, nil) == "/api/posts"
      assert PostView.url_for([], nil) == "/api/posts"
      assert PostView.url_for(%Post{id: 1}, nil) == "/api/posts/1"
      assert PostView.url_for([], %Plug.Conn{}) == "http://www.example.com/api/posts"
      assert PostView.url_for(%Post{id: 1}, %Plug.Conn{}) == "http://www.example.com/api/posts/1"

      assert View.url_for_relationship(PostView, [], "comments", %Plug.Conn{}) ==
               "http://www.example.com/api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, "comments", %Plug.Conn{}) ==
               "http://www.example.com/api/posts/1/relationships/comments"
    end
  end

  describe "url_for/2 when host configured" do
    setup do
      Application.put_env(:jsonapi, :host, "www.otherhost.com")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :host)
      end)

      {:ok, []}
    end

    test "uses configured host instead of that on Conn" do
      assert View.url_for_relationship(PostView, [], "comments", %Plug.Conn{}) ==
               "http://www.otherhost.com/api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, "comments", %Plug.Conn{}) ==
               "http://www.otherhost.com/api/posts/1/relationships/comments"

      assert View.url_for(PostView, [], %Plug.Conn{}) == "http://www.otherhost.com/api/posts"

      assert View.url_for(PostView, %Post{id: 1}, %Plug.Conn{}) ==
               "http://www.otherhost.com/api/posts/1"
    end
  end

  describe "url_for/2 when scheme configured" do
    setup do
      Application.put_env(:jsonapi, :scheme, "ftp")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :scheme)
      end)

      {:ok, []}
    end

    test "uses configured scheme instead of that on Conn" do
      assert PostView.url_for([], %Plug.Conn{}) == "ftp://www.example.com/api/posts"
      assert PostView.url_for(%Post{id: 1}, %Plug.Conn{}) == "ftp://www.example.com/api/posts/1"

      assert View.url_for_relationship(PostView, [], "comments", %Plug.Conn{}) ==
               "ftp://www.example.com/api/posts/relationships/comments"

      assert View.url_for_relationship(PostView, %Post{id: 1}, "comments", %Plug.Conn{}) ==
               "ftp://www.example.com/api/posts/1/relationships/comments"
    end
  end

  describe "url_for_pagination/3" do
    setup do
      {:ok, conn: Plug.Conn.fetch_query_params(%Plug.Conn{})}
    end

    test "with pagination information", %{conn: conn} do
      assert View.url_for_pagination(PostView, nil, conn, %{}) ==
               "http://www.example.com/api/posts"

      assert View.url_for_pagination(PostView, nil, conn, %{number: 1, size: 10}) ==
               "http://www.example.com/api/posts?page%5Bnumber%5D=1&page%5Bsize%5D=10"
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params =
        Kernel.update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert View.url_for_pagination(PostView, nil, conn_with_query_params, %{number: 1, size: 10}) ==
               "http://www.example.com/api/posts?comments%5B%5D=5&comments%5B%5D=2&page%5Bnumber%5D=1&page%5Bsize%5D=10"

      assert View.url_for_pagination(PostView, nil, conn_with_query_params, %{}) ==
               "http://www.example.com/api/posts?comments%5B%5D=5&comments%5B%5D=2"
    end
  end

  test "render/2 is defined when 'Phoenix' is loaded" do
    assert {:render, 2} in CommentView.__info__(:functions)
  end

  test "show renders with data, conn" do
    data =
      CommentView.render("show.json", %{data: %Comment{id: 1, body: "hi"}, conn: %Plug.Conn{}})

    assert data.data.attributes.body == "hi"
  end

  test "show renders with data, conn, meta" do
    data =
      CommentView.render("show.json", %{
        data: %Comment{id: 1, body: "hi"},
        conn: %Plug.Conn{},
        meta: %{total_pages: 100}
      })

    assert data.meta.total_pages == 100
  end

  test "index renders with data, conn" do
    data =
      CommentView.render("index.json", %{
        data: [%Comment{id: 1, body: "hi"}],
        conn: Plug.Conn.fetch_query_params(%Plug.Conn{})
      })

    data = Enum.at(data.data, 0)
    assert data.attributes.body == "hi"
  end

  test "index renders with data, conn, meta" do
    data =
      CommentView.render("index.json", %{
        data: [%Comment{id: 1, body: "hi"}],
        conn: Plug.Conn.fetch_query_params(%Plug.Conn{}),
        meta: %{total_pages: 100}
      })

    assert data.meta.total_pages == 100
  end

  test "visible_fields/2 returns all field names by default" do
    for field <- View.visible_fields(UserView, %Plug.Conn{}),
        do: assert(field in [:age, :first_name, :last_name, :full_name, :username, :password])
  end

  test "visible_fields/2 trims returned field names to only those requested" do
    config = %JSONAPI.Config{fields: %{PostView.type() => [:body]}}
    conn = %Plug.Conn{assigns: %{jsonapi_query: config}}

    assert [:body] == View.visible_fields(PostView, conn)
  end

  test "attributes/2 can return only requested fields" do
    post = %Post{body: "Chunky", title: "Bacon"}
    config = %JSONAPI.Config{fields: %{PostView.type() => [:body]}}
    conn = %Plug.Conn{assigns: %{jsonapi_query: config}}

    assert %{body: "Chunky"} == PostView.attributes(post, conn)
  end
end
