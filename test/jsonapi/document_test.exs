defmodule JSONAPI.DocumentTest do
  use ExUnit.Case, async: false

  alias JSONAPI.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Paginator,
    Plug.Request,
    View
  }

  alias JSONAPI.TestSupport.APIs.{DefaultAPI, OtherNamespaceAPI}
  alias JSONAPI.TestSupport.Resources.{Comment, Company, Industry, Post, Tag, User}

  alias JSONAPI.TestSupport.Views.{
    CommentView,
    ExpensiveResourceView,
    NotIncludedView,
    PostView,
    UserView
  }

  alias Plug.Parsers

  test "serialize includes meta as top level member" do
    assert %Document{meta: %{total_pages: 10}} =
             Document.serialize(
               %Document{data: %Post{id: 1, text: "Hello"}, meta: %{total_pages: 10}},
               PostView
             )

    assert %Document{meta: nil} =
             Document.serialize(%Document{data: %Comment{id: 1}}, CommentView)
  end

  test "serialize only includes meta if provided" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    assert %Document{data: %ResourceObject{meta: %{meta_text: "meta_Hello"}}} =
             Document.serialize(%Document{data: %Post{id: 1, text: "Hello"}}, PostView)

    assert %Document{meta: nil} =
             Document.serialize(%Document{data: %Comment{id: 1}}, CommentView, conn)
  end

  test "serialize handles singular objects" do
    conn =
      Plug.Test.conn(:get, "/?include=bestComments.user")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

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
               attributes: %{"text" => text, "body" => body},
               relationships: relationships,
               meta: %{meta_text: "meta_Hello"},
               links: %{self: self}
             },
             included: included,
             links: links
           } = Document.serialize(%Document{data: post}, PostView, conn)

    assert links[:self] == View.url_for(PostView, post, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()
    assert ^self = View.url_for(PostView, post, conn)
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
      Plug.Test.conn(:get, "/?include=bestComments.user")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    assert %Document{
             data: data,
             included: included
           } = Document.serialize(%Document{data: [post, post, post]}, PostView, conn)

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

      assert attributes["text"] == post.text
      assert attributes["body"] == post.body

      assert links.self == View.url_for(PostView, post, conn)
      assert map_size(resource.relationships) == 2
    end)
  end

  test "serialize handles an empty relationship" do
    conn =
      Plug.Test.conn(:get, "/?include=author")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    post = %Post{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %User{id: 2, username: "jason"},
      best_comments: []
    }

    assert %Document{
             data: %ResourceObject{
               id: id,
               type: type,
               attributes: attributes,
               links: links,
               relationships: relationships
             },
             included: included
           } = Document.serialize(%Document{data: post}, PostView, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()

    assert attributes["text"] == post.text
    assert attributes["body"] == post.body

    assert links.self == View.url_for(PostView, post, conn)
    assert map_size(relationships) == 2

    assert %RelationshipObject{data: []} = relationships["bestComments"]

    assert Enum.count(included) == 1
  end

  test "serialize handles a nil relationship" do
    conn =
      Plug.Test.conn(:get, "/?include=author")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

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
           } = Document.serialize(%Document{data: post}, PostView, conn)

    assert ^id = PostView.id(post)
    assert ^type = PostView.type()

    assert attributes["text"] == post.text
    assert attributes["body"] == post.body

    assert links.self == View.url_for(PostView, post, conn)
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
                 "author" => %RelationshipObject{
                   links: %{self: "/posts/1/relationships/author"}
                 }
               }
             }
           } = Document.serialize(%Document{data: post}, PostView)
  end

  test "serialize handles a relationship self link on an index request" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    assert %Document{links: %{self: "http://www.example.com/posts"}} =
             Document.serialize(%Document{data: []}, PostView, conn)
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
      Plug.Test.conn(:get, "/?include=bestComments.user")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    assert %Document{data: %ResourceObject{relationships: relationships}, included: included} =
             Document.serialize(%Document{data: post}, PostView, conn)

    assert relationships["author"].links.self ==
             "http://www.example.com/posts/1/relationships/author"

    assert Enum.count(included) == 4
  end

  test "includes from the query" do
    user = %User{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %Company{id: 2, name: "acme"}
    }

    conn =
      Plug.Test.conn(:get, "/?include=company")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: UserView))

    encoded = Document.serialize(%Document{data: user}, UserView, conn)

    assert encoded.data.relationships["company"].links.self ==
             "http://www.example.com/users/1/relationships/company"

    assert Enum.count(encoded.included) == 1
  end

  test "includes nested items from the query" do
    user = %User{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %Company{id: 2, name: "acme", industry: %Industry{id: 4, name: "stuff"}}
    }

    conn =
      Plug.Test.conn(:get, "/?include=company.industry")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: OtherNamespaceAPI)
      |> Request.call(Request.init(view: UserView))

    %Document{
      data: %ResourceObject{
        relationships: %{
          "company" => %RelationshipObject{
            links: %{self: "http://www.example.com/somespace/users/1/relationships/company"}
          }
        }
      },
      included: included
    } = Document.serialize(%Document{data: user}, UserView, conn)

    assert Enum.count(included) == 2
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
      Plug.Test.conn(:get, "/?include=company.industry.tags")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: OtherNamespaceAPI)
      |> Request.call(Request.init(view: UserView))

    encoded = Document.serialize(%Document{data: user}, UserView, conn)

    assert encoded.data.relationships["company"].links.self ==
             "http://www.example.com/somespace/users/1/relationships/company"

    assert Enum.count(encoded.included) == 4
  end

  describe "when configured to camelize fields" do
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

      conn =
        Plug.Test.conn(:get, "/")
        |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
        |> JSONAPI.Plug.call(api: DefaultAPI)
        |> Request.call(Request.init(view: PostView))

      assert %Document{
               data: %ResourceObject{
                 attributes: attributes,
                 relationships: relationships
               },
               included: included
             } = Document.serialize(%Document{data: post}, PostView, conn)

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
               links: %{self: "http://www.example.com/posts/1/relationships/bestComments"}
             } = relationships["bestComments"]
    end
  end

  describe "when configured to dasherize fields" do
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

      conn =
        Plug.Test.conn(:get, "/")
        |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
        |> JSONAPI.Plug.call(api: OtherNamespaceAPI)
        |> Request.call(Request.init(view: PostView))

      assert %Document{
               data: %ResourceObject{attributes: attributes, relationships: relationships},
               included: included
             } = Document.serialize(%Document{data: post}, PostView, conn)

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
               data: [%ResourceIdentifierObject{id: "5", type: "comment"}],
               links: %{
                 self: "http://www.example.com/somespace/posts/1/relationships/bestComments"
               }
             } = relationships["bestComments"]
    end
  end

  test "serialize does not merge `included` if not configured" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: NotIncludedView))

    post = %Post{
      id: 1,
      author: %User{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"}
    }

    assert %Document{included: []} =
             Document.serialize(%Document{data: post}, NotIncludedView, conn)
  end

  test "serialize includes pagination links if page-based pagination is requested" do
    conn =
      :get
      |> Plug.Test.conn("/my-type?page[page]=2&page[size]=1")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    page = conn.assigns.jsonapi.page
    first = Paginator.url_for(PostView, [%Post{id: 1}], conn, %{page | "page" => 1})
    last = Paginator.url_for(PostView, [%Post{id: 1}], conn, %{page | "page" => 3})
    self = Paginator.url_for(PostView, [%Post{id: 1}], conn, page)

    assert %Document{links: links} =
             Document.serialize(
               %Document{data: [%Post{id: 1, text: ""}], meta: %{total_pages: 3, total_items: 3}},
               PostView,
               conn,
               total_pages: 3,
               total_items: 3
             )

    assert links.first == first
    assert links.last == last
    assert links.next == last
    assert links.prev == first
    assert links.self == self
  end

  test "serialize does not include pagination links if they are not defined" do
    assert %Document{links: links} = Document.serialize(%Document{data: [%User{id: 1}]}, UserView)

    refute links[:first]
    refute links[:last]
    refute links[:next]
    refute links[:prev]
  end

  test "serialize can include arbitrary, user-defined, links" do
    assert %Document{
             links: %{
               self: "/expensive-post/1",
               queue: "/expensive-post/queue/1",
               promotions: %{
                 href: "/promotions?rel=1",
                 meta: %{
                   title: "Stuff you might be interested in"
                 }
               }
             }
           } = Document.serialize(%Document{data: %Post{id: 1}}, ExpensiveResourceView)
  end

  test "serialize returns a null data if it receives a null data" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: ExpensiveResourceView))

    assert %Document{
             data: nil,
             links: %{self: "http://www.example.com/expensive-post"}
           } = Document.serialize(%Document{data: nil}, ExpensiveResourceView, conn)
  end

  test "serialize handles query parameters in self links" do
    conn =
      Plug.Test.conn(:get, "/my-type?page[page]=2&page[size]=1")
      |> Parsers.call(Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason))
      |> JSONAPI.Plug.call(api: DefaultAPI)
      |> Request.call(Request.init(view: PostView))

    assert %Document{
             data: [%ResourceObject{links: %{self: "http://www.example.com/posts/1"}}],
             links: %{self: "http://www.example.com/posts?page%5Bpage%5D=2&page%5Bsize%5D=1"}
           } =
             Document.serialize(
               %Document{data: [%Post{id: 1, text: ""}], meta: %{total_pages: 3, total_items: 3}},
               PostView,
               conn
             )
  end
end
