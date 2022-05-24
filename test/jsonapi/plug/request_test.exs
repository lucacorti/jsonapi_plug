defmodule JSONAPI.Plug.RequestTest do
  use ExUnit.Case
  use Plug.Test

  import JSONAPI.Plug.Request

  doctest JSONAPI.Plug.Request

  alias JSONAPI.{Document, Exceptions.InvalidQuery, Plug.Request}
  alias JSONAPI.TestSupport.APIs.DefaultAPI
  alias JSONAPI.TestSupport.Resources.{Car, User}
  alias JSONAPI.TestSupport.Views.{CarView, MyPostView, UserView}
  alias Plug.Conn

  defmodule ExampleCamelCasePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: DefaultAPI
    plug Request, view: CarView

    plug :return

    def return(conn, _opts) do
      send_resp(conn, 200, "success")
    end
  end

  defmodule ExampleUnderscorePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: UnderscoringAPI
    plug Request, view: CarView

    plug :return

    def return(conn, _opts) do
      send_resp(conn, 200, "success")
    end
  end

  defmodule ExamplePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: DefaultAPI
    plug Request, view: CarView
  end

  describe "request body" do
    test "Ignores bodyless requests" do
      assert %Conn{private: %{jsonapi: %JSONAPI{request: %Document{data: nil}}}} =
               Plug.Test.conn("GET", "/")
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExamplePlug.call([])
    end

    test "ignores non-jsonapi.org format params" do
      req_body =
        Jason.encode!(%{
          "data" => %{"id" => "1", "type" => "car", "attributes" => %{}},
          "some-nonsense" => "yup"
        })

      assert %Conn{private: %{jsonapi: %JSONAPI{request: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExamplePlug.call([])
    end

    test "works with basic list of data" do
      req_body =
        Jason.encode!(%{
          "data" => [
            %{"id" => "1", "type" => "car"},
            %{"id" => "2", "type" => "car"}
          ]
        })

      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   request: %Document{
                     data: [
                       %Car{id: "1"},
                       %Car{id: "2"}
                     ]
                   }
                 }
               }
             } =
               Plug.Test.conn("POST", "/relationships", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExamplePlug.call([])
    end

    test "deserializes attribute key names" do
      req_body =
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

      assert %Conn{private: %{jsonapi: %JSONAPI{request: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExamplePlug.call([])
    end

    test "deserializes dasherized attribute key names and underscores them" do
      req_body =
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
          }
        })

      assert %Conn{private: %{jsonapi: %JSONAPI{request: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExampleUnderscorePlug.call([])
    end

    test "deserializes camelcased attribute key names and underscores them" do
      req_body =
        Jason.encode!(%{
          "data" => %{
            "id" => "1",
            "type" => "car",
            "attributes" => %{
              "someNonsense" => true,
              "fooBar" => true,
              "someMap" => %{
                "nested_key" => true
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
          }
        })

      assert %Conn{private: %{jsonapi: %JSONAPI{request: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> ExampleCamelCasePlug.call([])
    end

    test "converts attributes and relationships to flattened data structure" do
      assert %Document{data: %User{id: "1"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "foo-bar" => "true"
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
                   }
                 }
               })
    end

    test "converts to many relationship" do
      assert %Document{data: %User{id: "1"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
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
                 }
               })
    end

    test "converts polymorphic" do
      assert %Document{data: %User{id: "1"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
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
                 }
               })
    end

    test "processes single includes" do
      assert %Document{data: %User{id: "1", first_name: "Jerome"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "first_name" => "Jerome"
                     }
                   },
                   "included" => [
                     %{
                       "attributes" => %{
                         "name" => "Tara"
                       },
                       "id" => "234",
                       "type" => "friend"
                     }
                   ]
                 }
               })
    end

    test "processes has many includes" do
      assert %Document{data: %User{id: "1", first_name: "Jerome"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => %{
                       "first_name" => "Jerome"
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
                 }
               })
    end

    test "processes simple array of data" do
      assert %Document{
               data: [
                 %User{id: "1"},
                 %User{id: "2"}
               ]
             } =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => [
                     %{"id" => "1", "type" => "user"},
                     %{"id" => "2", "type" => "user"}
                   ]
                 }
               })
    end

    test "processes empty keys" do
      assert %Document{data: %User{id: "1"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => %{
                     "id" => "1",
                     "type" => "user",
                     "attributes" => nil
                   },
                   "relationships" => nil,
                   "included" => nil
                 }
               })
    end

    test "processes empty data" do
      assert %Document{data: %User{id: "1"}} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{
                   "data" => %{
                     "id" => "1",
                     "type" => "user"
                   }
                 }
               })
    end

    test "processes nil data" do
      assert %Document{data: nil} =
               Document.deserialize(UserView, %Conn{
                 body_params: %{"data" => nil}
               })
    end
  end

  describe "query parameters" do
    test "parse_sort/2 turns sorts into valid ecto sorts" do
      config = struct(JSONAPI, opts: [sort: ~w(name title)], view: MyPostView)

      assert %JSONAPI{sort: [asc: :name, asc: :title]} =
               parse_sort(config, %{"sort" => "name,title"})

      assert %JSONAPI{sort: [asc: :name]} = parse_sort(config, %{"sort" => "name"})
      assert %JSONAPI{sort: [desc: :name]} = parse_sort(config, %{"sort" => "-name"})

      assert %JSONAPI{sort: [asc: :name, desc: :title]} =
               parse_sort(config, %{"sort" => "name,-title"})
    end

    test "parse_sort/2 raises on invalid sorts" do
      config = struct(JSONAPI, view: MyPostView)

      assert_raise InvalidQuery, "invalid sort, name for type my-type", fn ->
        parse_sort(config, %{"sort" => "name"})
      end
    end

    test "parse_filter/2 turns filters key/val pairs" do
      config = struct(JSONAPI, opts: [filter: ~w(name)], view: MyPostView)

      assert %JSONAPI{filter: [name: "jason"]} =
               parse_filter(config, %{"filter" => %{"name" => "jason"}})
    end

    test "parse_filter/2 raises on invalid filters" do
      config = struct(JSONAPI, view: MyPostView)

      assert_raise InvalidQuery, "invalid filter, noop for type my-type", fn ->
        parse_filter(config, %{"filter" => %{"noop" => "jason"}})
      end
    end

    test "parse_include/2 turns an include string into a keyword list" do
      config = struct(JSONAPI, view: MyPostView)

      assert %JSONAPI{include: [:author, comments: :user]} =
               parse_include(config, %{"include" => "author,comments.user"})

      assert %JSONAPI{include: [:author]} = parse_include(config, %{"include" => "author"})

      assert %JSONAPI{include: [:comments, :author]} =
               parse_include(config, %{"include" => "comments,author"})

      assert %JSONAPI{include: [comments: :user]} =
               parse_include(config, %{"include" => "comments.user"})

      assert %JSONAPI{include: [:best_friends]} =
               parse_include(config, %{"include" => "best_friends"})

      assert %JSONAPI{include: [author: :top_posts]} =
               parse_include(config, %{"include" => "author.top-posts"})
    end

    test "parse_include/2 errors with invalid includes" do
      config = struct(JSONAPI, view: MyPostView)

      assert_raise InvalidQuery, "invalid include, user for type my-type", fn ->
        parse_include(config, %{"include" => "user,comments.author"})
      end

      assert_raise InvalidQuery, "invalid include, comments.author for type my-type", fn ->
        parse_include(config, %{"include" => "comments.author"})
      end

      assert_raise InvalidQuery, "invalid include, comments.author.user for type my-type", fn ->
        parse_include(config, %{"include" => "comments.author.user"})
      end

      assert_raise InvalidQuery, "invalid include, fake_rel for type my-type", fn ->
        assert parse_include(config, %{"include" => "fake-rel"})
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      config = struct(JSONAPI, view: MyPostView)

      assert %JSONAPI{fields: %{"my-type" => [:text]}} =
               parse_fields(config, %{"fields" => %{"my-type" => "text"}})
    end

    test "parse_fields/2 raises on invalid parsing" do
      config = struct(JSONAPI, view: MyPostView)

      assert_raise InvalidQuery, "invalid fields, blag for type my-type", fn ->
        parse_fields(config, %{"fields" => %{"my-type" => "blag"}})
      end

      assert_raise InvalidQuery, "invalid fields, username for type my-type", fn ->
        parse_fields(config, %{"fields" => %{"my-type" => "username"}})
      end
    end

    test "parse_pagination/2 turns a fields map into a map of pagination values" do
      config = struct(JSONAPI, view: MyPostView)
      assert %JSONAPI{page: %{}} = parse_pagination(config, config)

      assert %JSONAPI{page: %{"cursor" => "cursor"}} =
               parse_pagination(config, %{"page" => %{"cursor" => "cursor"}})

      assert %JSONAPI{page: %{"limit" => "1"}} =
               parse_pagination(config, %{"page" => %{"limit" => "1"}})

      assert %JSONAPI{page: %{"offset" => "1"}} =
               parse_pagination(config, %{"page" => %{"offset" => "1"}})

      assert %JSONAPI{page: %{"page" => "1"}} =
               parse_pagination(config, %{"page" => %{"page" => "1"}})

      assert %JSONAPI{page: %{"size" => "1"}} =
               parse_pagination(config, %{"page" => %{"size" => "1"}})
    end

    test "put_as_tree/3 builds the path" do
      items = [:test, :the, :path]
      assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
    end
  end
end
