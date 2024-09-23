defmodule JSONAPIPlug.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidQuery
  alias JSONAPIPlug.TestSupport.APIs.DefaultAPI
  alias JSONAPIPlug.TestSupport.Resources.{CarResource, MyPostResource, UserResource}
  alias Plug.Conn

  defmodule CarResourcePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: CarResource
  end

  defmodule UserResourcePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: UserResource
  end

  defmodule MyPostResourcePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: MyPostResource
  end

  describe "request body" do
    test "Ignores bodyless requests" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: %{}}}} =
               conn(:get, "/")
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarResourcePlug.call([])
    end

    test "ignores non-jsonapi.org format params" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: %{"id" => "1"}}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{"id" => "1", "type" => "car", "attributes" => %{}},
                   "some-nonsense" => "yup"
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarResourcePlug.call([])
    end

    test "works with basic list of data" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{params: [%{"id" => "1"}, %{"id" => "2"}]}
               }
             } =
               conn(:post, "/relationships", %{
                 "data" => [
                   %{"id" => "1", "type" => "car"},
                   %{"id" => "2", "type" => "car"}
                 ]
               })
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarResourcePlug.call([])
    end

    test "deserializes attribute key names" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{params: %{"id" => "1", "model" => "panda"}}
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "car",
                     "attributes" => %{
                       "some-nonsense" => true,
                       "foo-bar" => true,
                       "some-map" => %{
                         "nested-key" => true
                       },
                       "model" => "panda"
                     },
                     "relationships" => %{
                       "baz" => %{
                         "data" => %{
                           "id" => "2",
                           "type" => "baz"
                         }
                       }
                     }
                   },
                   "filter" => %{
                     "dog-breed" => "Corgi"
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarResourcePlug.call([])
    end

    test "converts to many relationship" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: %{
                     "id" => "1",
                     "age" => 42,
                     "first_name" => "pippo",
                     "top_posts" => [%{"id" => "2"}, %{"id" => "3"}]
                   }
                 }
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "age" => 42,
                       "firstName" => "pippo"
                     },
                     "relationships" => %{
                       "topPosts" => %{
                         "data" => [
                           %{"id" => "2", "type" => "my-type"},
                           %{"id" => "3", "type" => "my-type"}
                         ]
                       }
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "converts polymorphic" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: %{"id" => "1"}}}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "foo-bar" => true
                     },
                     "relationships" => %{
                       "baz" => %{
                         "data" => [
                           %{"id" => "2", "type" => "baz"},
                           %{"id" => "3", "type" => "yooper"}
                         ]
                       }
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "processes single includes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: %{
                     "id" => "1",
                     "first_name" => "Jerome",
                     "company_id" => "234",
                     "company" => %{"id" => "234", "name" => "Tara"}
                   }
                 }
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "firstName" => "Jerome"
                     },
                     "relationships" => %{
                       "company" => %{
                         "data" => %{"id" => "234", "type" => "company"}
                       }
                     }
                   },
                   "included" => [
                     %{
                       "attributes" => %{
                         "name" => "Tara"
                       },
                       "id" => "234",
                       "type" => "company"
                     }
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "processes has many includes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: %{
                     "id" => "1",
                     "first_name" => "Jerome"
                   }
                 }
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "firstName" => "Jerome"
                     }
                   },
                   "included" => [
                     %{
                       "id" => "234",
                       "type" => "friend",
                       "attributes" => %{
                         "name" => "Tara"
                       },
                       "relationships" => %{
                         "baz" => %{
                           "data" => %{
                             "id" => "2",
                             "type" => "baz"
                           }
                         },
                         "boo" => %{
                           "data" => nil
                         }
                       }
                     },
                     %{
                       "attributes" => %{
                         "name" => "Wild Bill"
                       },
                       "id" => "0012",
                       "type" => "friend"
                     },
                     %{
                       "attributes" => %{
                         "title" => "Sr"
                       },
                       "id" => "456",
                       "type" => "organization"
                     }
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "processes simple array of data" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: [
                     %{"id" => "1"},
                     %{"id" => "2"}
                   ]
                 }
               }
             } =
               conn(
                 :post,
                 "/relationships",
                 Jason.encode!(%{
                   "data" => [
                     %{"id" => "1", "type" => "user"},
                     %{"id" => "2", "type" => "user"}
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "processes empty keys" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: %{"id" => "1"}
                 }
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => nil
                   },
                   "relationships" => nil,
                   "included" => nil
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end

    test "processes empty attributes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   params: %{"id" => "1"}
                 }
               }
             } =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user"
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])
    end
  end

  describe "query parameters" do
    test "parse_sort/2 turns sorts into valid ecto sorts" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, asc: :title]}}} =
               conn(:get, "/?sort=body,title")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body]}}} =
               conn(:get, "/?sort=body")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [desc: :body]}}} =
               conn(:get, "/?sort=-body")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, desc: :title]}}} =
               conn(:get, "/?sort=body,-title")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :author_first_name]}}} =
               conn(:get, "/?sort=author.firstName")
               |> MyPostResourcePlug.call([])
    end

    test "parse_sort/2 raises on invalid sorts" do
      assert_raise InvalidQuery, "invalid parameter sort=name for type my-type", fn ->
        MyPostResourcePlug.call(conn(:get, "/?sort=name"), [])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_prop for type user", fn ->
        MyPostResourcePlug.call(conn(:get, "/?sort=author.noProp"), [])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_rel for type my-type", fn ->
        MyPostResourcePlug.call(conn(:get, "/?sort=noRel"), [])
      end
    end

    test "parse_filter/2 stores filters" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{filter: %{"name" => "jason"}}}} =
               conn(:get, "/?filter[name]=jason")
               |> MyPostResourcePlug.call([])
    end

    test "parse_include/2 turns an include string into a keyword list" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author,comments.user")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:author])
      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=comments,author")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:comments])
      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=comments.user")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=best_friends")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:best_friends])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author.top-posts,author.company")
               |> MyPostResourcePlug.call([])

      assert [] = get_in(include, [:author, :top_posts])
      assert [] = get_in(include, [:author, :company])
    end

    test "parse_include/2 errors with invalid includes" do
      assert_raise InvalidQuery, "invalid parameter include=user for type my-type", fn ->
        conn(:get, "/?include=user,comments.author")
        |> MyPostResourcePlug.call([])
      end

      assert_raise InvalidQuery,
                   "invalid parameter include=author for type comment",
                   fn ->
                     conn(:get, "/?include=comments.author")
                     |> MyPostResourcePlug.call([])
                   end

      assert_raise InvalidQuery,
                   "invalid parameter include=author.user for type comment",
                   fn ->
                     conn(:get, "/?include=comments.author.user")
                     |> MyPostResourcePlug.call([])
                   end

      assert_raise InvalidQuery, "invalid parameter include=fake_rel for type my-type", fn ->
        conn(:get, "/?include=fake-rel")
        |> MyPostResourcePlug.call([])
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{fields: %{"my-type" => [:text]}}}} =
               conn(:get, "/?fields[my-type]=text")
               |> MyPostResourcePlug.call([])
    end

    test "parse_fields/2 raises on invalid parsing" do
      assert_raise InvalidQuery, "invalid parameter fields=blag for type my-type", fn ->
        conn(:get, "/?fields[my-type]=blag")
        |> MyPostResourcePlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter fields=username for type my-type", fn ->
        conn(:get, "/?fields[my-type]=username")
        |> MyPostResourcePlug.call([])
      end
    end

    test "parse_page/2 turns a fields map into a map of pagination values" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: nil}}} =
               conn(:get, "/")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"cursor" => "cursor"}}}} =
               conn(:get, "/?page[cursor]=cursor")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"limit" => "1"}}}} =
               conn(:get, "/?page[limit]=1")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"offset" => "1"}}}} =
               conn(:get, "/?page[offset]=1")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"page" => "1"}}}} =
               conn(:get, "/?page[page]=1")
               |> MyPostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"size" => "1"}}}} =
               conn(:get, "/?page[size]=1")
               |> MyPostResourcePlug.call([])
    end
  end
end
