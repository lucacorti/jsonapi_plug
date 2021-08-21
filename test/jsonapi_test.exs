defmodule JSONAPITest do
  use ExUnit.Case
  use Plug.Test

  import JSONAPI

  doctest JSONAPI

  alias JSONAPI.View
  alias JSONAPI.TestSupport.Resources.{Company, Industry, Post, Tag, User}
  alias JSONAPI.TestSupport.Views.PostView
  alias Plug.Conn

  @default_data %Post{
    id: 1,
    text: "Hello",
    body: "Hi",
    author: %User{username: "jason", id: 2},
    other_user: %User{username: "josh", id: 3}
  }

  defmodule MyPostPlug do
    use Plug.Builder

    alias Plug.Conn

    plug JSONAPI.QueryParser,
      view: PostView,
      sort: [:text],
      filter: [:text]

    plug :passthrough

    defp passthrough(conn, _) do
      resp =
        PostView
        |> View.render(conn.assigns[:data], conn, conn.assigns[:meta])
        |> Jason.encode!()

      Conn.send_resp(conn, 200, resp)
    end
  end

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
    end)

    {:ok, []}
  end

  test "handles simple requests" do
    conn =
      :get
      |> conn("/posts?include=author")
      |> Conn.assign(:data, [@default_data])
      |> Conn.assign(:meta, %{total_pages: 1})
      |> Conn.fetch_query_params()
      |> MyPostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "type" => "post",
                 "attributes" => %{
                   "body" => "Hi",
                   "text" => "Hello",
                   "excerpt" => "He"
                 },
                 "relationships" =>
                   %{
                     "author" => %{
                       "data" => %{
                         "id" => "2",
                         "type" => "user"
                       }
                     },
                     "other_user" => _other_user
                   } = relationships
               }
             ],
             "included" => [
               %{
                 "id" => "2",
                 "type" => "user"
               }
             ],
             "links" => _links,
             "meta" => %{
               "total_pages" => 1
             }
           } = Jason.decode!(conn.resp_body)

    assert map_size(relationships) == 3
  end

  test "handles includes properly" do
    conn =
      :get
      |> conn("/posts?include=author,other_user")
      |> Conn.assign(:data, [@default_data])
      |> Conn.fetch_query_params()
      |> MyPostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "type" => "post",
                 "relationships" =>
                   %{
                     "author" => %{
                       "data" => %{
                         "id" => "2",
                         "type" => "user"
                       }
                     },
                     "other_user" => %{
                       "data" => %{
                         "id" => "3",
                         "type" => "user"
                       }
                     }
                   } = relationships
               }
               | _rest
             ],
             "included" => [_ | _] = included,
             "links" => _links
           } = Jason.decode!(conn.resp_body)

    assert map_size(relationships) == 3
    assert Enum.sort(Map.keys(relationships)) == ["author", "best_comments", "other_user"]

    assert Enum.find(included, fn
             %{"id" => "2", "type" => "user"} -> true
             _ -> false
           end)

    assert Enum.find(included, fn
             %{"id" => "3", "type" => "user"} -> true
             _ -> false
           end)
  end

  test "handles empty includes properly" do
    conn =
      :get
      |> conn("/posts?include=")
      |> Plug.Conn.assign(:data, [@default_data])
      |> Plug.Conn.fetch_query_params()
      |> MyPostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    assert Map.has_key?(json, "data")
    data_list = Map.get(json, "data")

    assert Enum.count(data_list) == 1
    [data | _] = data_list
    assert Map.get(data, "type") == "mytype"
    assert Map.get(data, "id") == "1"

    relationships = Map.get(data, "relationships")
    assert map_size(relationships) == 2
    assert Enum.sort(Map.keys(relationships)) == ["author", "other_user"]
    author_rel = Map.get(relationships, "author")

    assert get_in(author_rel, ["data", "type"]) == "user"
    assert get_in(author_rel, ["data", "id"]) == "2"

    other_user = Map.get(relationships, "other_user")

    # not included
    assert get_in(other_user, ["data", "type"]) == "user"
    assert get_in(other_user, ["data", "id"]) == "3"

    assert Map.has_key?(json, "included")
    included = Map.get(json, "included")
    assert is_list(included)
    # author is atuomatically included
    assert Enum.count(included) == 1
  end

  test "handles deep nested includes properly" do
    posts = [
      %Post{
        id: 1,
        text: "Hello",
        body: "Hi",
        author: %User{username: "jason", id: 2},
        other_user: %User{
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
      }
    ]

    conn =
      :get
      |> conn("/posts?include=other_user.company.industry.tags")
      |> Conn.assign(:data, posts)
      |> Conn.fetch_query_params()
      |> MyPostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "type" => "post",
                 "relationships" => %{
                   "author" =>
                     %{
                       "data" => %{
                         "id" => "2",
                         "type" => "user"
                       }
                     } = relationships,
                   "other_user" => %{
                     "data" => %{
                       "id" => "1",
                       "type" => "user"
                     }
                   }
                 }
               }
             ],
             "included" => [_ | _] = included,
             "links" => _links
           } = Jason.decode!(conn.resp_body)

    assert map_size(relationships) == 2
    assert Enum.count(included) == 5

    assert Enum.find(included, fn
             %{"id" => "1", "type" => "user"} -> true
             _ -> false
           end)

    assert Enum.find(included, fn
             %{"id" => "2", "type" => "company"} -> true
             _ -> false
           end)

    assert Enum.find(included, fn
             %{"id" => "4", "type" => "industry"} -> true
             _ -> false
           end)

    assert Enum.find(included, fn
             %{"id" => "3", "type" => "tag"} -> true
             _ -> false
           end)

    assert Enum.find(included, fn
             %{"id" => "4", "type" => "tag"} -> true
             _ -> false
           end)
  end

  describe "with an underscored API" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :underscore)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "handles sparse fields properly" do
      conn =
        :get
        |> conn("/posts?include=other_user.company&fields[post]=text,excerpt,first_character")
        |> Conn.assign(:data, [@default_data])
        |> Conn.fetch_query_params()
        |> MyPostPlug.call([])

      assert %{
               "data" => [
                 %{
                   "attributes" => %{
                     "text" => "Hello",
                     "excerpt" => "He",
                     "first_character" => "H"
                   }
                 }
               ]
             } = Jason.decode!(conn.resp_body)
    end
  end

  describe "with a dasherized API" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :dasherize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "handles sparse fields properly" do
      conn =
        :get
        |> conn("/posts?include=other_user.company&fields[post]=text,first-character")
        |> Conn.assign(:data, [@default_data])
        |> Conn.fetch_query_params()
        |> MyPostPlug.call([])

      assert %{
               "data" => [
                 %{
                   "attributes" => %{
                     "text" => "Hello",
                     "first-character" => "H"
                   }
                 }
               ]
             } = Jason.decode!(conn.resp_body)
    end

    test "handles empty sparse fields properly" do
      conn =
        :get
        |> conn("/posts?include=other_user.company&fields[mytype]=")
        |> Plug.Conn.assign(:data, [@default_data])
        |> Plug.Conn.fetch_query_params()
        |> MyPostPlug.call([])

      assert %{
               "data" => [
                 %{"attributes" => attributes}
               ]
             } = Jason.decode!(conn.resp_body)

      assert %{} == attributes
    end
  end

  test "omits explicit nil meta values as per http://jsonapi.org/format/#document-meta" do
    conn =
      :get
      |> conn("/posts")
      |> Conn.assign(:data, [@default_data])
      |> Conn.assign(:meta, nil)
      |> Conn.fetch_query_params()
      |> MyPostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    refute Map.has_key?(json, "meta")
  end

  test "omits implicit nil meta values as per http://jsonapi.org/format/#document-meta" do
    conn =
      :get
      |> conn("/posts")
      |> Conn.assign(:data, [@default_data])
      |> Conn.fetch_query_params()
      |> MyPostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    refute Map.has_key?(json, "meta")
  end
end
