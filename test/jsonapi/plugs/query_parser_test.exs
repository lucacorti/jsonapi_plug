defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case

  import JSONAPI.QueryParser

  alias JSONAPI.Config
  alias JSONAPI.Exceptions.InvalidQuery
  alias JSONAPI.SupportTest.{Comment, Post, User}

  defmodule MyView do
    use JSONAPI.View, resource: Post

    @impl JSONAPI.View
    def attributes, do: [:id, :text, :body]

    @impl JSONAPI.View
    def type, do: "my-type"

    @impl JSONAPI.View
    def relationships do
      [
        author: JSONAPI.QueryParserTest.UserView,
        comments: JSONAPI.QueryParserTest.CommentView,
        best_friends: JSONAPI.QueryParserTest.UserView
      ]
    end
  end

  defmodule UserView do
    use JSONAPI.View, resource: User

    @impl JSONAPI.View
    def attributes, do: [:id, :username]

    @impl JSONAPI.View
    def type, do: "user"

    @impl JSONAPI.View
    def relationships, do: [top_posts: MyView]
  end

  defmodule CommentView do
    use JSONAPI.View, resource: Comment

    @impl JSONAPI.View
    def attributes, do: [:id, :text]

    @impl JSONAPI.View
    def type, do: "comment"

    @impl JSONAPI.View
    def relationships, do: [user: JSONAPI.QueryParserTest.UserView]
  end

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
    end)

    {:ok, []}
  end

  test "parse_sort/2 turns sorts into valid ecto sorts" do
    config = struct(Config, opts: [sort: ~w(name title)], view: MyView)
    assert parse_sort(config, "name,title").sort == [asc: :name, asc: :title]
    assert parse_sort(config, "name").sort == [asc: :name]
    assert parse_sort(config, "-name").sort == [desc: :name]
    assert parse_sort(config, "name,-title").sort == [asc: :name, desc: :title]
  end

  test "parse_sort/2 raises on invalid sorts" do
    config = struct(Config, opts: [], view: MyView)

    assert_raise InvalidQuery, "invalid sort, name for type my-type", fn ->
      parse_sort(config, "name")
    end
  end

  test "parse_filter/2 turns filters key/val pairs" do
    config = struct(Config, opts: [filter: ~w(name)], view: MyView)
    filter = parse_filter(config, %{"name" => "jason"}).filter
    assert filter[:name] == "jason"
  end

  test "parse_filter/2 raises on invalid filters" do
    config = struct(Config, opts: [], view: MyView)

    assert_raise InvalidQuery, "invalid filter, noop for type my-type", fn ->
      parse_filter(config, %{"noop" => "jason"})
    end
  end

  test "parse_include/2 turns an include string into a keyword list" do
    config = struct(Config, view: MyView)
    assert parse_include(config, "author,comments.user").include == [:author, comments: :user]
    assert parse_include(config, "author").include == [:author]
    assert parse_include(config, "comments,author").include == [:comments, :author]
    assert parse_include(config, "comments.user").include == [comments: :user]
    assert parse_include(config, "best_friends").include == [:best_friends]
    assert parse_include(config, "author.top-posts").include == [author: :top_posts]
    assert parse_include(config, "").include == []
  end

  test "parse_include/2 errors with invalid includes" do
    config = struct(Config, view: MyView)

    assert_raise InvalidQuery, "invalid include, user for type my-type", fn ->
      parse_include(config, "user,comments.author")
    end

    assert_raise InvalidQuery, "invalid include, comments.author for type my-type", fn ->
      parse_include(config, "comments.author")
    end

    assert_raise InvalidQuery, "invalid include, comments.author.user for type my-type", fn ->
      parse_include(config, "comments.author.user")
    end

    assert_raise InvalidQuery, "invalid include, fake_rel for type my-type", fn ->
      assert parse_include(config, "fake-rel")
    end
  end

  test "parse_fields/2 turns a fields map into a map of validated fields" do
    config = struct(Config, view: MyView)
    assert parse_fields(config, %{"my-type" => "id,text"}).fields == %{"my-type" => [:id, :text]}
  end

  test "parse_fields/2 turns an empty fields map into an empty list" do
    config = struct(Config, view: MyView)
    assert parse_fields(config, %{"mytype" => ""}).fields == %{"mytype" => []}
  end

  test "parse_fields/2 raises on invalid parsing" do
    config = struct(Config, view: MyView)

    assert_raise InvalidQuery, "invalid fields, blag for type my-type", fn ->
      parse_fields(config, %{"my-type" => "blag"})
    end

    assert_raise InvalidQuery, "invalid fields, username for type my-type", fn ->
      parse_fields(config, %{"my-type" => "username"})
    end
  end

  test "get_view_for_type/2 using view.type as key" do
    assert get_view_for_type(MyView, "comment") == JSONAPI.QueryParserTest.CommentView
  end

  test "parse_pagination/2 turns a fields map into a map of pagination values" do
    config = struct(Config, view: MyView)
    assert parse_pagination(config, config.page).page == %{}
    assert parse_pagination(config, %{"limit" => "1"}).page == %{"limit" => "1"}
    assert parse_pagination(config, %{"offset" => "1"}).page == %{"offset" => "1"}
    assert parse_pagination(config, %{"page" => "1"}).page == %{"page" => "1"}
    assert parse_pagination(config, %{"size" => "1"}).page == %{"size" => "1"}
    assert parse_pagination(config, %{"cursor" => "cursor"}).page == %{"cursor" => "cursor"}
  end

  test "get_view_for_type/2 raises on invalid fields" do
    assert_raise InvalidQuery, "invalid fields, cupcake for type my-type", fn ->
      get_view_for_type(MyView, "cupcake")
    end
  end

  test "put_as_tree/3 builds the path" do
    items = [:test, :the, :path]
    assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
  end
end
