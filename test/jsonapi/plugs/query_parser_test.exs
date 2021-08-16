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

    assert %Config{sort: [asc: :name, asc: :title]} =
             parse_sort(config, %Config{sort: "name,title"})

    assert %Config{sort: [asc: :name]} = parse_sort(config, %Config{sort: "name"})
    assert %Config{sort: [desc: :name]} = parse_sort(config, %Config{sort: "-name"})

    assert %Config{sort: [asc: :name, desc: :title]} =
             parse_sort(config, %Config{sort: "name,-title"})
  end

  test "parse_sort/2 raises on invalid sorts" do
    config = struct(Config, opts: [], view: MyView)

    assert_raise InvalidQuery, "invalid sort, name for type my-type", fn ->
      parse_sort(config, %Config{sort: "name"})
    end
  end

  test "parse_filter/2 turns filters key/val pairs" do
    config = struct(Config, opts: [filter: ~w(name)], view: MyView)

    assert %Config{filter: [name: "jason"]} =
             parse_filter(config, %Config{filter: %{"name" => "jason"}})
  end

  test "parse_filter/2 raises on invalid filters" do
    config = struct(Config, opts: [], view: MyView)

    assert_raise InvalidQuery, "invalid filter, noop for type my-type", fn ->
      parse_filter(config, %Config{filter: %{"noop" => "jason"}})
    end
  end

  test "parse_include/2 turns an include string into a keyword list" do
    config = struct(Config, view: MyView)

    assert %Config{include: [:author, comments: :user]} =
             parse_include(config, %Config{include: "author,comments.user"})

    assert %Config{include: [:author]} = parse_include(config, %Config{include: "author"})

    assert %Config{include: [:comments, :author]} =
             parse_include(config, %Config{include: "comments,author"})

    assert %Config{include: [comments: :user]} =
             parse_include(config, %Config{include: "comments.user"})

    assert %Config{include: [:best_friends]} =
             parse_include(config, %Config{include: "best_friends"})

    assert %Config{include: [author: :top_posts]} =
             parse_include(config, %Config{include: "author.top-posts"})
  end

  test "parse_include/2 errors with invalid includes" do
    config = struct(Config, view: MyView)

    assert_raise InvalidQuery, "invalid include, user for type my-type", fn ->
      parse_include(config, %Config{include: "user,comments.author"})
    end

    assert_raise InvalidQuery, "invalid include, comments.author for type my-type", fn ->
      parse_include(config, %Config{include: "comments.author"})
    end

    assert_raise InvalidQuery, "invalid include, comments.author.user for type my-type", fn ->
      parse_include(config, %Config{include: "comments.author.user"})
    end

    assert_raise InvalidQuery, "invalid include, fake_rel for type my-type", fn ->
      assert parse_include(config, %Config{include: "fake-rel"})
    end
  end

  test "parse_fields/2 turns a fields map into a map of validated fields" do
    config = struct(Config, view: MyView)

    assert %Config{fields: %{"my-type" => [:id, :text]}} =
             parse_fields(config, %Config{fields: %{"my-type" => "id,text"}})
  end

  test "parse_fields/2 turns an empty fields map into an empty list" do
    config = struct(Config, view: MyView)
    assert parse_fields(config, %{"mytype" => ""}).fields == %{"mytype" => []}
  end

  test "parse_fields/2 raises on invalid parsing" do
    config = struct(Config, view: MyView)

    assert_raise InvalidQuery, "invalid fields, blag for type my-type", fn ->
      parse_fields(config, %Config{fields: %{"my-type" => "blag"}})
    end

    assert_raise InvalidQuery, "invalid fields, username for type my-type", fn ->
      parse_fields(config, %Config{fields: %{"my-type" => "username"}})
    end
  end

  test "get_view_for_type/2 using view.type as key" do
    assert get_view_for_type(MyView, "comment") == JSONAPI.QueryParserTest.CommentView
  end

  test "parse_pagination/2 turns a fields map into a map of pagination values" do
    config = struct(Config, view: MyView)
    assert %Config{page: %{}} = parse_pagination(config, config)

    assert %Config{page: %{"limit" => "1"}} =
             parse_pagination(config, %Config{page: %{"limit" => "1"}})

    assert %Config{page: %{"offset" => "1"}} =
             parse_pagination(config, %Config{page: %{"offset" => "1"}})

    assert %Config{page: %{"page" => "1"}} =
             parse_pagination(config, %Config{page: %{"page" => "1"}})

    assert %Config{page: %{"size" => "1"}} =
             parse_pagination(config, %Config{page: %{"size" => "1"}})

    assert %Config{page: %{"cursor" => "cursor"}} =
             parse_pagination(config, %Config{page: %{"cursor" => "cursor"}})
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
