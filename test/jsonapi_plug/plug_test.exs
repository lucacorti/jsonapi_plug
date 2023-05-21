defmodule JSONAPIPlug.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.Exceptions.InvalidQuery
  alias JSONAPIPlug.TestSupport.APIs.DefaultAPI
  alias JSONAPIPlug.TestSupport.Resources.{Car, Post, User}
  alias Plug.Conn

  defmodule CarPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: Car
  end

  defmodule UserPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: User
  end

  defmodule PostPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, resource: Post
  end

  describe "request body" do
    test "Ignores bodyless requests" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{params: %{}}}} =
               conn(:get, "/")
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarPlug.call([])
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
               |> CarPlug.call([])
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
               |> CarPlug.call([])
    end

    test "deserializes attribute key names" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{params: %{"id" => "1"}}
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
                       }
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
               |> CarPlug.call([])
    end

    test "converts to many relationship" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{params: %{"id" => "1"}}
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
                       "foo-bar" => true
                     },
                     "relationships" => %{
                       "baz" => %{
                         "data" => [
                           %{"id" => "2", "type" => "baz"},
                           %{"id" => "3", "type" => "baz"}
                         ]
                       }
                     }
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserPlug.call([])
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
               |> UserPlug.call([])
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
               |> UserPlug.call([])
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
               |> UserPlug.call([])
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
               |> UserPlug.call([])
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
               |> UserPlug.call([])
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
               |> UserPlug.call([])
    end
  end

  describe "query parameters" do
    test "parse_sort/2 turns sorts into valid ecto sorts" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, asc: :text]}}} =
               conn(:get, "/?sort=body,text")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body]}}} =
               conn(:get, "/?sort=body")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [desc: :body]}}} =
               conn(:get, "/?sort=-body")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, desc: :text]}}} =
               conn(:get, "/?sort=body,-text")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :author_first_name]}}} =
               conn(:get, "/?sort=author.firstName")
               |> PostPlug.call([])
    end

    test "parse_sort/2 raises on invalid sorts" do
      assert_raise InvalidQuery, "invalid parameter sort=name for type post", fn ->
        conn(:get, "/?sort=name")
        |> PostPlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_prop for type user", fn ->
        conn(:get, "/?sort=author.noProp")
        |> PostPlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter sort=no_rel for type post", fn ->
        conn(:get, "/?sort=noRel")
        |> PostPlug.call([])
      end
    end

    test "parse_filter/2 stores filters" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{filter: %{"name" => "jason"}}}} =
               conn(:get, "/?filter[name]=jason")
               |> PostPlug.call([])
    end

    test "parse_include/2 turns an include string into a keyword list" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author,bestComments.user")
               |> PostPlug.call([])

      assert [] = get_in(include, [:author])
      assert [] = get_in(include, [:best_comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author")
               |> PostPlug.call([])

      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=bestComments,author")
               |> PostPlug.call([])

      assert [] = get_in(include, [:best_comments])
      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=bestComments.user")
               |> PostPlug.call([])

      assert [] = get_in(include, [:best_comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author.top-posts,author.company")
               |> PostPlug.call([])

      assert [] = get_in(include, [:author, :top_posts])
      assert [] = get_in(include, [:author, :company])
    end

    test "parse_include/2 errors with invalid includes" do
      assert_raise InvalidQuery, "invalid parameter include=user for type post", fn ->
        conn(:get, "/?include=user,comments.author")
        |> PostPlug.call([])
      end

      assert_raise InvalidQuery,
                   "invalid parameter include=comments.author for type post",
                   fn ->
                     conn(:get, "/?include=comments.author")
                     |> PostPlug.call([])
                   end

      assert_raise InvalidQuery,
                   "invalid parameter include=comments.author.user for type post",
                   fn ->
                     conn(:get, "/?include=comments.author.user")
                     |> PostPlug.call([])
                   end

      assert_raise InvalidQuery, "invalid parameter include=fake_rel for type post", fn ->
        conn(:get, "/?include=fake-rel")
        |> PostPlug.call([])
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{fields: %{"post" => [:text]}}}} =
               conn(:get, "/?fields[post]=text")
               |> PostPlug.call([])
    end

    test "parse_fields/2 raises on invalid parsing" do
      assert_raise InvalidQuery, "invalid parameter fields=blag for type post", fn ->
        conn(:get, "/?fields[post]=blag")
        |> PostPlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter fields=username for type post", fn ->
        conn(:get, "/?fields[post]=username")
        |> PostPlug.call([])
      end
    end

    test "parse_page/2 turns a fields map into a map of pagination values" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: nil}}} =
               conn(:get, "/")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"cursor" => "cursor"}}}} =
               conn(:get, "/?page[cursor]=cursor")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"limit" => "1"}}}} =
               conn(:get, "/?page[limit]=1")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"offset" => "1"}}}} =
               conn(:get, "/?page[offset]=1")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"page" => "1"}}}} =
               conn(:get, "/?page[page]=1")
               |> PostPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"size" => "1"}}}} =
               conn(:get, "/?page[size]=1")
               |> PostPlug.call([])
    end
  end
end
