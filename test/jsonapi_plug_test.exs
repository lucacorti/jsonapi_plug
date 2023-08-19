defmodule JSONAPIPlugTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Resource
  alias JSONAPIPlug.TestSupport.Resources.{Company, Industry, Post, Tag, User}
  alias Plug.{Conn, Parsers}

  @default_data %Post{
    id: 1,
    text: "Hello",
    body: "Hi",
    author: %User{username: "jason", id: 2},
    other_user: %User{username: "josh", id: 3}
  }

  defmodule PostPlug do
    use Plug.Builder

    plug Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: JSONAPIPlug.TestSupport.APIs.DefaultAPI, resource: Post
    plug :passthrough

    defp passthrough(conn, _) do
      resp =
        Resource.render(conn, conn.assigns[:data], conn.assigns[:links], conn.assigns[:meta])
        |> Jason.encode!()

      send_resp(conn, 200, resp)
    end
  end

  test "handles simple requests" do
    conn =
      conn(:get, "/posts?include=author")
      |> Conn.assign(:data, [@default_data])
      |> PostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "type" => "post",
                 "attributes" => %{"body" => "Hi", "text" => "Hello", "excerpt" => "He"},
                 "relationships" =>
                   %{
                     "author" => %{"data" => %{"id" => "2", "type" => "user"}},
                     "otherUser" => %{"data" => %{"id" => "3", "type" => "user"}}
                   } = relationships
               }
             ],
             "included" => [
               %{"id" => "2", "type" => "user"}
             ]
           } = Jason.decode!(conn.resp_body)

    assert map_size(relationships) == 3
  end

  test "handles includes properly" do
    conn =
      conn(:get, "/posts?include=author,other_user")
      |> Conn.assign(:data, [@default_data])
      |> PostPlug.call([])

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
                     "bestComments" => _,
                     "otherUser" => %{
                       "data" => %{
                         "id" => "3",
                         "type" => "user"
                       }
                     }
                   } = relationships
               }
             ],
             "included" => [_ | _] = included
           } = Jason.decode!(conn.resp_body)

    assert map_size(relationships) == 3

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
      conn(:get, "/posts?include=")
      |> Plug.Conn.assign(:data, [@default_data])
      |> PostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    assert Map.has_key?(json, "data")
    data_list = Map.get(json, "data")

    assert Enum.count(data_list) == 1
    [data | _] = data_list
    assert Map.get(data, "type") == "post"
    assert Map.get(data, "id") == "1"

    relationships = Map.get(data, "relationships")
    assert map_size(relationships) == 3
    assert Enum.sort(Map.keys(relationships)) == ["author", "bestComments", "otherUser"]
    author_rel = Map.get(relationships, "author")

    assert author_rel["data"]["type"] == "user"
    assert author_rel["data"]["id"] == "2"

    other_user = Map.get(relationships, "otherUser")

    # not included
    assert other_user["data"]["type"] == "user"
    assert other_user["data"]["id"] == "3"
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
      conn(:get, "/posts?include=other_user.company.industry.tags")
      |> Conn.assign(:data, posts)
      |> PostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "type" => "post",
                 "relationships" => %{
                   "author" => %{
                     "data" => %{
                       "id" => "2",
                       "type" => "user"
                     }
                   },
                   "otherUser" => %{
                     "data" => %{
                       "id" => "1",
                       "type" => "user"
                     }
                   }
                 }
               }
             ],
             "included" => [_ | _] = included
           } = Jason.decode!(conn.resp_body)

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

  test "handles deep nested includes properly when an include is unreachable" do
    posts = [
      %Post{
        id: 1,
        text: "Hello",
        body: "Hi",
        author: %User{username: "jason", id: 2}
      }
    ]

    conn =
      conn(:get, "/posts?include=author.company.industry")
      |> Conn.assign(:data, posts)
      |> MyPostPlug.call([])

    assert %{
             "data" => [
               %{
                 "id" => "1",
                 "relationships" => %{
                   "author" => %{
                     "data" => %{"id" => "2", "type" => "user"}
                   },
                   "bestComments" => %{
                     "data" => []
                   }
                 },
                 "type" => "post",
                 "attributes" => %{
                   "body" => "Hi",
                   "excerpt" => "He",
                   "firstCharacter" => "H",
                   "fullDescription" => nil,
                   "insertedAt" => nil,
                   "text" => "Hello"
                 }
               }
             ],
             "included" => [
               %{
                 "attributes" => %{
                   "age" => nil,
                   "firstName" => nil,
                   "fullName" => " ",
                   "lastName" => nil,
                   "password" => nil,
                   "username" => "jason"
                 },
                 "id" => "2",
                 "type" => "user"
               }
             ]
           } = Jason.decode!(conn.resp_body)
  end

  describe "with an underscored API" do
    test "handles sparse fields properly" do
      conn =
        conn(:get, "/posts?include=other_user.company&fields[post]=text,excerpt,first_character")
        |> Conn.assign(:data, [@default_data])
        |> PostPlug.call([])

      assert %{
               "data" => [
                 %{
                   "attributes" => %{
                     "text" => "Hello",
                     "excerpt" => "He",
                     "firstCharacter" => "H"
                   }
                 }
               ]
             } = Jason.decode!(conn.resp_body)
    end
  end

  describe "with a dasherized API" do
    test "handles sparse fields properly" do
      conn =
        conn(:get, "/posts?include=other_user.company&fields[post]=text,first-character")
        |> Conn.assign(:data, [@default_data])
        |> PostPlug.call([])

      assert %{
               "data" => [
                 %{
                   "attributes" => %{
                     "text" => "Hello",
                     "firstCharacter" => "H"
                   }
                 }
               ]
             } = Jason.decode!(conn.resp_body)
    end

    test "handles empty sparse fields properly" do
      conn =
        conn(:get, "/posts?include=other_user.company&fields[post]=")
        |> Plug.Conn.assign(:data, [@default_data])
        |> PostPlug.call([])

      assert %{"data" => [resource]} = Jason.decode!(conn.resp_body)

      assert map_size(Map.get(resource, "attributes", %{})) == 0
    end
  end

  test "omits explicit nil meta values as per http://jsonapi.org/format/#document-meta" do
    conn =
      conn(:get, "/posts")
      |> Conn.assign(:data, [@default_data])
      |> Conn.assign(:meta, nil)
      |> PostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    refute Map.has_key?(json, "meta")
  end

  test "omits implicit nil meta values as per http://jsonapi.org/format/#document-meta" do
    conn =
      conn(:get, "/posts")
      |> Conn.assign(:data, [@default_data])
      |> PostPlug.call([])

    json = conn.resp_body |> Jason.decode!()

    refute Map.has_key?(json, "meta")
  end
end
