defmodule JSONAPI.DocumentTest do
  use ExUnit.Case, async: false

  alias JSONAPI.{
    Config,
    Document,
    Document.RelationshipObject,
    Document.ResourceObject,
    QueryParser,
    View
  }

  alias JSONAPI.SupportTest.{Comment, Company, Industry, Post, Tag, User}

  alias Plug.Conn

  defmodule PostView do
    use JSONAPI.View, resource: Post

    @impl JSONAPI.View
    def attributes, do: [:text, :body, :full_description, :inserted_at]

    @impl JSONAPI.View
    def meta(%Post{} = post, _conn), do: %{meta_text: "meta_#{post.text}"}

    @impl JSONAPI.View
    def type, do: "my-type"

    @impl JSONAPI.View
    def relationships do
      [
        author: JSONAPI.DocumentTest.UserView,
        best_comments: JSONAPI.DocumentTest.CommentView
      ]
    end
  end

  defmodule PageBasedPaginator do
    @moduledoc """
    Page based pagination strategy
    """

    @behaviour JSONAPI.Paginator

    @impl true
    def paginate(view, resources, conn, page, options) do
      number =
        page
        |> Map.get("page", "0")
        |> String.to_integer()

      size =
        page
        |> Map.get("size", "0")
        |> String.to_integer()

      total_pages =
        options
        |> Keyword.get(:total_pages, 0)

      %{
        first: View.url_for_pagination(view, resources, conn, %{page | "page" => "1"}),
        last: View.url_for_pagination(view, resources, conn, %{page | "page" => total_pages}),
        next: next_link(resources, view, conn, number, size, total_pages),
        prev: previous_link(resources, view, conn, number, size),
        self: View.url_for_pagination(view, resources, conn, %{size: size, page: number})
      }
    end

    defp next_link(resources, view, conn, page, size, total_pages)
         when page < total_pages,
         do: View.url_for_pagination(view, resources, conn, %{size: size, page: page + 1})

    defp next_link(_resources, _view, _conn, _page, _size, _total_pages),
      do: nil

    defp previous_link(resources, view, conn, page, size)
         when page > 1,
         do: View.url_for_pagination(view, resources, conn, %{size: size, page: page - 1})

    defp previous_link(_resources, _view, _conn, _page, _size),
      do: nil
  end

  defmodule PaginatedPostView do
    use JSONAPI.View, resource: Post, paginator: PageBasedPaginator

    @impl JSONAPI.View
    def attributes, do: [:text, :body, :full_description, :inserted_at]

    @impl JSONAPI.View
    def type, do: "post"
  end

  defmodule UserView do
    use JSONAPI.View, resource: User

    @impl JSONAPI.View
    def attributes, do: [:username, :first_name, :last_name]

    @impl JSONAPI.View
    def type, do: "user"

    @impl JSONAPI.View
    def relationships do
      [company: JSONAPI.DocumentTest.CompanyView]
    end
  end

  defmodule CompanyView do
    use JSONAPI.View, resource: Company

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def type, do: "company"

    @impl JSONAPI.View
    def relationships do
      [industry: JSONAPI.DocumentTest.IndustryView]
    end
  end

  defmodule IndustryView do
    use JSONAPI.View, resource: Industry

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def type, do: "industry"

    @impl JSONAPI.View
    def relationships do
      [tags: JSONAPI.DocumentTest.TagView]
    end
  end

  defmodule TagView do
    use JSONAPI.View, resource: Tag

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def type, do: "tag"

    @impl JSONAPI.View
    def relationships, do: []
  end

  defmodule CommentView do
    use JSONAPI.View, resource: Comment

    @impl JSONAPI.View
    def attributes, do: [:text]

    @impl JSONAPI.View
    def relationships, do: [user: JSONAPI.DocumentTest.UserView]
  end

  defmodule NotIncludedView do
    use JSONAPI.View, resource: Post, type: "not-included"

    @impl JSONAPI.View
    def attributes, do: [:foo]

    @impl JSONAPI.View
    def relationships do
      [author: JSONAPI.DocumentTest.UserView, best_comments: JSONAPI.DocumentTest.CommentView]
    end
  end

  defmodule ExpensiveResourceView do
    use JSONAPI.View, resource: Post

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def type, do: "expensive-post"

    @impl JSONAPI.View
    def links(nil, _conn), do: %{}

    @impl JSONAPI.View
    def links(data, _conn) do
      %{
        queue: "/expensive-post/queue/#{data.id}",
        promotions: %{
          href: "/promotions?rel=#{data.id}",
          meta: %{
            title: "Stuff you might be interested in"
          }
        }
      }
    end
  end

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
    end)

    {:ok, []}
  end

  test "serialize includes meta as top level member" do
    assert %Document{meta: %{total_pages: 10}} =
             Document.serialize(PostView, %Post{id: 1, text: "Hello"}, nil, %{total_pages: 10})

    assert %Document{meta: nil} = Document.serialize(CommentView, %Comment{id: 1}, nil, nil)
  end

  test "serialize only includes meta if provided" do
    assert %Document{data: %ResourceObject{meta: %{meta_text: "meta_Hello"}}} =
             Document.serialize(PostView, %Post{id: 1, text: "Hello"}, nil)

    assert %Document{meta: nil} = Document.serialize(CommentView, %Comment{id: 1}, nil)
  end

  test "serialize handles singular objects" do
    conn = Conn.assign(%Conn{}, :jsonapi_query, %Config{include: [best_comments: [:user]]})

    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: [
        %Comment{id: 5, text: "greatest comment ever", user: %User{id: 4, username: "jack"}},
        %Comment{id: 6, text: "not so great", user: %User{id: 2, username: "jason"}}
      ]
    }

    assert %Document{
             data: %ResourceObject{
               id: id,
               type: type,
               attributes: %{text: text, body: body},
               relationships: relationships,
               meta: %{meta_text: "meta_Hello"},
               links: %{self: self}
             },
             included: included,
             links: links
           } = Document.serialize(PostView, post, conn)

    assert links[:self] == PostView.url_for(post, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()
    assert ^self = PostView.url_for(post, conn)
    assert ^text = post.text
    assert ^body = post.body

    assert map_size(relationships) == 2
    assert Enum.count(included) == 4
  end

  test "serialize handles a list" do
    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: [
        %Comment{id: 5, text: "greatest comment ever", user: %User{id: 4, username: "jack"}},
        %Comment{id: 6, text: "not so great", user: %User{id: 2, username: "jason"}}
      ]
    }

    conn =
      %Conn{}
      |> Conn.assign(:jsonapi_query, %Config{include: [best_comments: [:user]]})
      |> Conn.fetch_query_params()

    assert %Document{
             data: data,
             included: included
           } = Document.serialize(PostView, [post, post, post], conn)

    assert Enum.count(data) == 3
    assert Enum.count(included) == 4

    Enum.each(data, fn %ResourceObject{
                         id: id,
                         type: type,
                         attributes: attributes,
                         links: links
                       } = resource ->
      assert ^id = PostView.id(post)
      assert ^type = PostView.type()

      assert attributes[:text] == post.text
      assert attributes[:body] == post.body

      assert links[:self] == PostView.url_for(post, conn)
      assert map_size(resource.relationships) == 2
    end)
  end

  test "serialize handles an empty relationship" do
    conn = Conn.assign(%Conn{}, :jsonapi_query, %Config{include: [:author]})

    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: []
    }

    %Document{
      data: %ResourceObject{
        id: id,
        type: type,
        attributes: attributes,
        links: links,
        relationships: relationships
      },
      included: included
    } = Document.serialize(PostView, post, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()

    assert attributes[:text] == post.text
    assert attributes[:body] == post.body

    assert links[:self] == PostView.url_for(post, conn)
    assert map_size(relationships) == 2

    assert %RelationshipObject{data: []} = relationships[:best_comments]

    assert Enum.count(included) == 1
  end

  test "serialize handles a nil relationship" do
    conn = Conn.assign(%Conn{}, :jsonapi_query, %Config{include: [:author]})

    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: nil
    }

    assert %Document{
             data: %ResourceObject{
               id: id,
               type: type,
               attributes: attributes,
               relationships: relationships
             },
             links: links,
             included: included
           } = Document.serialize(PostView, post, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()

    assert attributes[:text] == post.text
    assert attributes[:body] == post.body

    assert links[:self] == PostView.url_for(post, conn)
    assert map_size(relationships) == 1
    assert Enum.count(included) == 1
  end

  test "serialize handles a relationship self link on a show request" do
    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: []
    }

    assert %Document{
             data: %ResourceObject{
               relationships: %{
                 author: %RelationshipObject{
                   links: %{self: "/my-type/1/relationships/author"}
                 }
               }
             }
           } = Document.serialize(PostView, post, nil)
  end

  test "serialize handles a relationship self link on an index request" do
    assert %Document{links: %{self: "http://www.example.com/my-type"}} =
             Document.serialize(PostView, [], Conn.fetch_query_params(%Conn{}))
  end

  test "serialize handles including from the query" do
    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: [
        %Comment{id: 5, text: "greatest comment ever", user: %User{id: 4, username: "jack"}},
        %Comment{id: 6, text: "not so great", user: %User{id: 2, username: "jason"}}
      ]
    }

    conn =
      %Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [best_comments: :user]
          }
        }
      }
      |> Conn.fetch_query_params()

    assert %Document{data: %ResourceObject{relationships: relationships}, included: included} =
             Document.serialize(PostView, post, conn)

    assert relationships.author.links.self ==
             "http://www.example.com/my-type/1/relationships/author"

    assert Enum.count(included) == 4
  end

  test "includes from the query when not included by default" do
    user = %User{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %Company{id: 2, name: "acme"}
    }

    conn =
      %Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [:company]
          }
        }
      }
      |> Conn.fetch_query_params()

    encoded = Document.serialize(UserView, user, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 1
  end

  test "includes nested items from the query when not included by default" do
    user = %User{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %Company{id: 2, name: "acme", industry: %Industry{id: 4, name: "stuff"}}
    }

    conn =
      %Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [company: :industry]
          }
        }
      }
      |> Conn.fetch_query_params()

    encoded = Document.serialize(UserView, user, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 2
  end

  test "includes items nested 2 layers deep from the query when not included by default" do
    user = %User{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %Company{
        id: 2,
        name: "acme",
        industry: %Industry{
          id: 4,
          name: "stuff",
          tags: [
            %Tag{id: 3, name: "a tag"},
            %Tag{id: 4, name: "another tag"}
          ]
        }
      }
    }

    conn =
      %Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [company: [industry: :tags]]
          }
        }
      }
      |> Conn.fetch_query_params()

    encoded = Document.serialize(UserView, user, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 4
  end

  describe "when configured to camelize fields" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :camelize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "serialize properly camelizes both attributes and relationships" do
      post = %Post{
        id: 1,
        text: "Hello",
        inserted_at: NaiveDateTime.utc_now(),
        body: "Hello world",
        full_description: "This_is_my_description",
        author: %User{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
        best_comments: [
          %Comment{
            id: 5,
            text: "greatest comment ever",
            user: %User{id: 4, username: "jack", last_name: "bronds"}
          }
        ]
      }

      assert %Document{
               data: %ResourceObject{
                 attributes: attributes,
                 relationships: relationships
               },
               included: included
             } = Document.serialize(PostView, post, nil)

      assert attributes["fullDescription"] == post.full_description
      assert attributes["insertedAt"] == post.inserted_at

      Enum.each(included, fn
        %ResourceObject{type: "user", id: "2", attributes: attributes} ->
          assert "bonds" = attributes["lastName"]

        %ResourceObject{type: "user", id: "4", attributes: attributes} ->
          assert "bronds" = attributes["lastName"]

        _ ->
          assert true
      end)

      assert %RelationshipObject{
               data: [%{id: "5"} | _],
               links: %{self: "/my-type/1/relationships/bestComments"}
             } = relationships["bestComments"]
    end
  end

  describe "when configured to dasherize fields" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :dasherize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "serialize properly dasherizes both attributes and relationships" do
      post = %Post{
        id: 1,
        text: "Hello",
        inserted_at: NaiveDateTime.utc_now(),
        body: "Hello world",
        full_description: "This_is_my_description",
        author: %User{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
        best_comments: [
          %Comment{
            id: 5,
            text: "greatest comment ever",
            user: %User{id: 4, username: "jack", last_name: "bronds"}
          }
        ]
      }

      assert %Document{
               data: %ResourceObject{attributes: attributes, relationships: relationships},
               included: included
             } = Document.serialize(PostView, post, nil)

      assert attributes["full-description"] == post.full_description
      assert attributes["inserted-at"] == post.inserted_at

      Enum.each(included, fn
        %ResourceObject{type: "user", id: "2", attributes: attributes} ->
          assert "bonds" = attributes["last-name"]

        %ResourceObject{type: "user", id: "4", attributes: attributes} ->
          assert "bronds" = attributes["last-name"]

        _ ->
          assert true
      end)

      assert %RelationshipObject{
               data: [%{id: "5"} | _],
               links: %{self: "/my-type/1/relationships/best-comments"}
             } = relationships["best-comments"]
    end
  end

  test "serialize does not merge `included` if not configured" do
    post = %Post{
      id: 1,
      author: %User{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"}
    }

    assert %Document{included: []} = Document.serialize(NotIncludedView, post, nil)
  end

  test "serialize includes pagination links if page-based pagination is requested" do
    posts = [%Post{id: 1}]
    view = PaginatedPostView

    conn =
      :get
      |> Plug.Test.conn("/my-type?page[page]=2&page[size]=1")
      |> QueryParser.call(%Config{view: view, opts: []})
      |> Conn.fetch_query_params()

    %Document{links: links} =
      Document.serialize(PaginatedPostView, posts, conn, nil, total_pages: 3, total_items: 3)

    page = conn.assigns.jsonapi_query.page
    first = View.url_for_pagination(view, posts, conn, %{page | "page" => 1})
    last = View.url_for_pagination(view, posts, conn, %{page | "page" => 3})
    self = View.url_for_pagination(view, posts, conn, page)

    assert links[:first] == first
    assert links[:last] == last
    assert links[:next] == last
    assert links[:prev] == first
    assert links[:self] == self
  end

  test "serialize does not include pagination links if they are not defined" do
    users = [%User{id: 1}]

    assert %Document{links: links} =
             Document.serialize(UserView, users, Conn.fetch_query_params(%Conn{}))

    refute links[:first]
    refute links[:last]
    refute links[:next]
    refute links[:prev]
  end

  test "serialize can include arbitrary, user-defined, links" do
    post = %Post{id: 1}

    assert %{
             links: links
           } = Document.serialize(ExpensiveResourceView, post, nil)

    expected_links = %{
      self: "/expensive-post/#{post.id}",
      queue: "/expensive-post/queue/#{post.id}",
      promotions: %{
        href: "/promotions?rel=#{post.id}",
        meta: %{
          title: "Stuff you might be interested in"
        }
      }
    }

    assert expected_links == links
  end

  test "serialize returns a null data if it receives a null data" do
    assert %{
             data: data,
             links: links
           } = Document.serialize(ExpensiveResourceView, nil, nil)

    assert nil == data
    assert %{self: "/expensive-post"} == links
  end

  test "serialize handles query parameters in self links" do
    posts = [%Post{id: 1}]
    view = PaginatedPostView

    conn =
      :get
      |> Plug.Test.conn("/my-type?page[page]=2&page[size]=1")
      |> QueryParser.call(%Config{view: view, opts: []})
      |> Conn.fetch_query_params()

    %Document{data: data, links: links} =
      Document.serialize(PaginatedPostView, posts, conn, nil, total_pages: 3, total_items: 3)

    assert links[:self] ==
             "http://www.example.com/post?page%5Bpage%5D=2&page%5Bsize%5D=1"

    assert List.first(data).links[:self] ==
             "http://www.example.com/post/1"
  end
end
