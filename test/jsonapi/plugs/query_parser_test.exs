defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case

  import JSONAPI.QueryParser

  alias JSONAPI.Exceptions.InvalidQuery
  alias JSONAPI.TestSupport.Views.{CommentView, MyPostView}

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
    end)

    {:ok, []}
  end

  test "parse_sort/2 turns sorts into valid ecto sorts" do
    config = struct(JSONAPI, opts: [sort: ~w(name title)], view: MyPostView)

    assert %JSONAPI{sort: [asc: :name, asc: :title]} =
             parse_sort(config, %JSONAPI{sort: "name,title"})

    assert %JSONAPI{sort: [asc: :name]} = parse_sort(config, %JSONAPI{sort: "name"})
    assert %JSONAPI{sort: [desc: :name]} = parse_sort(config, %JSONAPI{sort: "-name"})

    assert %JSONAPI{sort: [asc: :name, desc: :title]} =
             parse_sort(config, %JSONAPI{sort: "name,-title"})
  end

  test "parse_sort/2 raises on invalid sorts" do
    config = struct(JSONAPI, opts: [], view: MyPostView)

    assert_raise InvalidQuery, "invalid sort, name for type my-type", fn ->
      parse_sort(config, %JSONAPI{sort: "name"})
    end
  end

  test "parse_filter/2 turns filters key/val pairs" do
    config = struct(JSONAPI, opts: [filter: ~w(name)], view: MyPostView)

    assert %JSONAPI{filter: [name: "jason"]} =
             parse_filter(config, %JSONAPI{filter: %{"name" => "jason"}})
  end

  test "parse_filter/2 raises on invalid filters" do
    config = struct(JSONAPI, opts: [], view: MyPostView)

    assert_raise InvalidQuery, "invalid filter, noop for type my-type", fn ->
      parse_filter(config, %JSONAPI{filter: %{"noop" => "jason"}})
    end
  end

  test "parse_include/2 turns an include string into a keyword list" do
    config = struct(JSONAPI, view: MyPostView)

    assert %JSONAPI{include: [:author, comments: :user]} =
             parse_include(config, %JSONAPI{include: "author,comments.user"})

    assert %JSONAPI{include: [:author]} = parse_include(config, %JSONAPI{include: "author"})

    assert %JSONAPI{include: [:comments, :author]} =
             parse_include(config, %JSONAPI{include: "comments,author"})

    assert %JSONAPI{include: [comments: :user]} =
             parse_include(config, %JSONAPI{include: "comments.user"})

    assert %JSONAPI{include: [:best_friends]} =
             parse_include(config, %JSONAPI{include: "best_friends"})

    assert %JSONAPI{include: [author: :top_posts]} =
             parse_include(config, %JSONAPI{include: "author.top-posts"})
  end

  test "parse_include/2 errors with invalid includes" do
    config = struct(JSONAPI, view: MyPostView)

    assert_raise InvalidQuery, "invalid include, user for type my-type", fn ->
      parse_include(config, %JSONAPI{include: "user,comments.author"})
    end

    assert_raise InvalidQuery, "invalid include, comments.author for type my-type", fn ->
      parse_include(config, %JSONAPI{include: "comments.author"})
    end

    assert_raise InvalidQuery, "invalid include, comments.author.user for type my-type", fn ->
      parse_include(config, %JSONAPI{include: "comments.author.user"})
    end

    assert_raise InvalidQuery, "invalid include, fake_rel for type my-type", fn ->
      assert parse_include(config, %JSONAPI{include: "fake-rel"})
    end
  end

  test "parse_fields/2 turns a fields map into a map of validated fields" do
    config = struct(JSONAPI, view: MyPostView)

    assert %JSONAPI{fields: %{"my-type" => [:text]}} =
             parse_fields(config, %JSONAPI{fields: %{"my-type" => "text"}})
  end

  test "parse_fields/2 turns an empty fields map into an empty list" do
    config = struct(Config, view: MyView)
    assert parse_fields(config, %{"mytype" => ""}).fields == %{"mytype" => []}
  end

  test "parse_fields/2 raises on invalid parsing" do
    config = struct(JSONAPI, view: MyPostView)

    assert_raise InvalidQuery, "invalid fields, blag for type my-type", fn ->
      parse_fields(config, %JSONAPI{fields: %{"my-type" => "blag"}})
    end

    assert_raise InvalidQuery, "invalid fields, username for type my-type", fn ->
      parse_fields(config, %JSONAPI{fields: %{"my-type" => "username"}})
    end
  end

  test "get_view_for_type/2 using view.type as key" do
    assert get_view_for_type(MyPostView, "comment") == CommentView
  end

  test "parse_pagination/2 turns a fields map into a map of pagination values" do
    config = struct(JSONAPI, view: MyPostView)
    assert %JSONAPI{page: %{}} = parse_pagination(config, config)

    assert %JSONAPI{page: %{"limit" => "1"}} =
             parse_pagination(config, %JSONAPI{page: %{"limit" => "1"}})

    assert %JSONAPI{page: %{"offset" => "1"}} =
             parse_pagination(config, %JSONAPI{page: %{"offset" => "1"}})

    assert %JSONAPI{page: %{"page" => "1"}} =
             parse_pagination(config, %JSONAPI{page: %{"page" => "1"}})

    assert %JSONAPI{page: %{"size" => "1"}} =
             parse_pagination(config, %JSONAPI{page: %{"size" => "1"}})

    assert %JSONAPI{page: %{"cursor" => "cursor"}} =
             parse_pagination(config, %JSONAPI{page: %{"cursor" => "cursor"}})
  end

  test "get_view_for_type/2 raises on invalid fields" do
    assert_raise InvalidQuery, "invalid fields, cupcake for type my-type", fn ->
      get_view_for_type(MyPostView, "cupcake")
    end
  end

  test "put_as_tree/3 builds the path" do
    items = [:test, :the, :path]
    assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
  end
end
