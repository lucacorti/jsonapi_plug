defmodule JSONAPIPlug.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidQuery
  alias JSONAPIPlug.TestSupport.Plugs.{CarResourcePlug, PostResourcePlug, UserResourcePlug}
  alias Plug.Conn

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

    test "processes single includes with lid" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "lid" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "firstName" => "Jerome"
                     },
                     "relationships" => %{
                       "company" => %{
                         "data" => %{"lid" => "234", "type" => "company"}
                       }
                     }
                   },
                   "included" => [
                     %{
                       "attributes" => %{
                         "name" => "Tara"
                       },
                       "lid" => "234",
                       "type" => "company"
                     }
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])

      refute jsonapi_plug.params["id"]
      assert jsonapi_plug.params["first_name"] == "Jerome"
      refute jsonapi_plug.params["company"]["id"]
      assert jsonapi_plug.params["company"]["name"] == "Tara"
    end

    test "processes has many includes" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{} = jsonapi_plug}} =
               conn(
                 :post,
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "lid" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "firstName" => "Jerome"
                     },
                     "relationships" => %{
                       "company" => %{
                         "data" => %{"lid" => "234", "type" => "company"}
                       },
                       "topPosts" => %{
                         "data" => [
                           %{"lid" => "1", "type" => "my-type"},
                           %{"lid" => "2", "type" => "my-type"},
                           %{"lid" => "3", "type" => "my-type"}
                         ]
                       }
                     }
                   },
                   "included" => [
                     %{
                       "lid" => "234",
                       "type" => "company",
                       "attributes" => %{
                         "name" => "Evil Corp"
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
                         "title" => "Wild Bill",
                         "body" => "A wild cowboy.",
                         "text" => "His rebel life."
                       },
                       "lid" => "1",
                       "type" => "my-type"
                     },
                     %{
                       "attributes" => %{
                         "title" => "Naughty Sean",
                         "body" => "A petty criminal.",
                         "text" => "His dangerous life."
                       },
                       "lid" => "2",
                       "type" => "my-type"
                     },
                     %{
                       "attributes" => %{
                         "title" => "Cool Vaughn",
                         "body" => "A chill dude.",
                         "text" => "His laid back life."
                       },
                       "lid" => "3",
                       "type" => "my-type"
                     }
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserResourcePlug.call([])

      refute jsonapi_plug.params["id"]
      assert jsonapi_plug.params["first_name"] == "Jerome"
      refute jsonapi_plug.params["company_id"]
      refute jsonapi_plug.params["company"]["id"]
      assert jsonapi_plug.params["company"]["name"] == "Evil Corp"
      refute get_in(jsonapi_plug.params, ["top_posts", Access.at(0), "id"])
      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(0), "body"]) == "A wild cowboy."
      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(0), "text"]) == "His rebel life."
      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(0), "title"]) == "Wild Bill"
      refute get_in(jsonapi_plug.params, ["top_posts", Access.at(1), "id"])

      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(1), "body"]) ==
               "A petty criminal."

      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(1), "text"]) ==
               "His dangerous life."

      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(1), "title"]) == "Naughty Sean"
      refute get_in(jsonapi_plug.params, ["top_posts", Access.at(2), "id"])
      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(2), "body"]) == "A chill dude."

      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(2), "text"]) ==
               "His laid back life."

      assert get_in(jsonapi_plug.params, ["top_posts", Access.at(2), "title"]) == "Cool Vaughn"
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
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body]}}} =
               conn(:get, "/?sort=body")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [desc: :body]}}} =
               conn(:get, "/?sort=-body")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, desc: :title]}}} =
               conn(:get, "/?sort=body,-title")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :author_first_name]}}} =
               conn(:get, "/?sort=author.firstName")
               |> PostResourcePlug.call([])
    end

    test "parse_sort/2 raises on invalid sorts" do
      assert_raise InvalidQuery, "invalid parameter sort=name for type post", fn ->
        PostResourcePlug.call(conn(:get, "/?sort=name"), [])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_prop for type user", fn ->
        PostResourcePlug.call(conn(:get, "/?sort=author.noProp"), [])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_rel for type post", fn ->
        PostResourcePlug.call(conn(:get, "/?sort=noRel"), [])
      end
    end

    test "parse_filter/2 stores filters" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{filter: %{"name" => "jason"}}}} =
               conn(:get, "/?filter[name]=jason")
               |> PostResourcePlug.call([])
    end

    test "parse_include/2 turns an include string into a keyword list" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author,best_comments.user")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:author])
      assert [] = get_in(include, [:best_comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=best_comments,author")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:best_comments])
      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=best_comments.user")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:best_comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=best_comments")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:best_comments])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author.top-posts,author.company")
               |> PostResourcePlug.call([])

      assert [] = get_in(include, [:author, :top_posts])
      assert [] = get_in(include, [:author, :company])
    end

    test "parse_include/2 errors with invalid includes" do
      assert_raise InvalidQuery, "invalid parameter include=user for type post", fn ->
        conn(:get, "/?include=user,comments.author")
        |> PostResourcePlug.call([])
      end

      assert_raise InvalidQuery,
                   "invalid parameter include=comments.author for type post",
                   fn ->
                     conn(:get, "/?include=comments.author")
                     |> PostResourcePlug.call([])
                   end

      assert_raise InvalidQuery,
                   "invalid parameter include=comments.author.user for type post",
                   fn ->
                     conn(:get, "/?include=comments.author.user")
                     |> PostResourcePlug.call([])
                   end

      assert_raise InvalidQuery, "invalid parameter include=fake_rel for type post", fn ->
        conn(:get, "/?include=fake-rel")
        |> PostResourcePlug.call([])
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{fields: %{"post" => [:text]}}}} =
               conn(:get, "/?fields[post]=text")
               |> PostResourcePlug.call([])
    end

    test "parse_fields/2 raises on invalid parsing" do
      assert_raise InvalidQuery, "invalid parameter fields=my-type for type post", fn ->
        conn(:get, "/?fields[my-type]=blag")
        |> PostResourcePlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter fields=my-type for type post", fn ->
        conn(:get, "/?fields[my-type]=username")
        |> PostResourcePlug.call([])
      end
    end

    test "parse_page/2 turns a fields map into a map of pagination values" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: nil}}} =
               conn(:get, "/")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"cursor" => "cursor"}}}} =
               conn(:get, "/?page[cursor]=cursor")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"limit" => "1"}}}} =
               conn(:get, "/?page[limit]=1")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"offset" => "1"}}}} =
               conn(:get, "/?page[offset]=1")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"page" => "1"}}}} =
               conn(:get, "/?page[page]=1")
               |> PostResourcePlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"size" => "1"}}}} =
               conn(:get, "/?page[size]=1")
               |> PostResourcePlug.call([])
    end
  end
end
