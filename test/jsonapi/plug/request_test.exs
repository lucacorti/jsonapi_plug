defmodule JSONAPI.Plug.RequestTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidQuery
  }

  alias JSONAPI.TestSupport.APIs.DefaultAPI
  alias JSONAPI.TestSupport.Views.{CarView, MyPostView, UserView}
  alias Plug.Conn

  defmodule CarViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: DefaultAPI
    plug JSONAPI.Plug.Request, view: CarView
  end

  defmodule UserViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: DefaultAPI
    plug JSONAPI.Plug.Request, view: UserView
  end

  defmodule MyPostViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Plug, api: DefaultAPI
    plug JSONAPI.Plug.Request, view: MyPostView
  end

  describe "request body" do
    test "Ignores bodyless requests" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{data: nil}
                 }
               }
             } =
               Plug.Test.conn("GET", "/")
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> CarViewPlug.call([])
    end

    test "ignores non-jsonapi.org format params" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{data: %ResourceObject{id: "1", type: "car"}}
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
                 "/",
                 Jason.encode!(%{
                   "data" => %{"id" => "1", "type" => "car", "attributes" => %{}},
                   "some-nonsense" => "yup"
                 })
               )
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> CarViewPlug.call([])
    end

    test "works with basic list of data" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: [%ResourceObject{id: "1"}, %ResourceObject{id: "2"}]
                   }
                 }
               }
             } =
               Plug.Test.conn("POST", "/relationships", %{
                 "data" => [
                   %{"id" => "1", "type" => "car"},
                   %{"id" => "2", "type" => "car"}
                 ]
               })
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> CarViewPlug.call([])
    end

    test "deserializes attribute key names" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "car",
                       attributes: %{
                         "some-nonsense" => true,
                         "foo-bar" => true,
                         "some-map" => %{
                           "nested-key" => true
                         }
                       },
                       relationships: %{
                         "baz" => %RelationshipObject{
                           data: %ResourceIdentifierObject{
                             id: "2",
                             type: "baz"
                           }
                         }
                       }
                     }
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> CarViewPlug.call([])
    end

    test "converts to many relationship" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "user",
                       attributes: %{"foo-bar" => true},
                       relationships: %{
                         "baz" => %RelationshipObject{
                           data: [
                             %ResourceIdentifierObject{id: "2", type: "baz"},
                             %ResourceIdentifierObject{id: "3", type: "baz"}
                           ]
                         }
                       }
                     }
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end

    test "converts polymorphic" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "user",
                       attributes: %{"foo-bar" => true},
                       relationships: %{
                         "baz" => %RelationshipObject{
                           data: [
                             %ResourceIdentifierObject{id: "2", type: "baz"},
                             %ResourceIdentifierObject{id: "3", type: "yooper"}
                           ]
                         }
                       }
                     }
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end

    test "processes single includes" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "user",
                       attributes: %{"firstName" => "Jerome"}
                     },
                     included: [
                       %ResourceObject{id: "234", type: "friend", attributes: %{"name" => "Tara"}}
                     ]
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
                       "attributes" => %{
                         "name" => "Tara"
                       },
                       "id" => "234",
                       "type" => "friend"
                     }
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end

    test "processes has many includes" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "user",
                       attributes: %{"firstName" => "Jerome"}
                     },
                     included: included
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])

      assert Enum.find(included, fn
               %ResourceObject{
                 id: "234",
                 type: "friend",
                 attributes: %{"name" => "Tara"},
                 relationships: %{
                   "baz" => %RelationshipObject{
                     data: %ResourceIdentifierObject{id: "2", type: "baz"}
                   },
                   "boo" => %RelationshipObject{data: nil}
                 }
               } ->
                 true

               _ ->
                 false
             end)

      assert Enum.find(included, fn
               %ResourceObject{id: "0012", type: "friend", attributes: %{"name" => "Wild Bill"}} ->
                 true

               _ ->
                 false
             end)

      assert Enum.find(included, fn
               %ResourceObject{id: "456", type: "organization", attributes: %{"title" => "Sr"}} ->
                 true

               _ ->
                 false
             end)
    end

    test "processes simple array of data" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: [
                       %ResourceObject{id: "1", type: "user"},
                       %ResourceObject{id: "2", type: "user"}
                     ]
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
                 "/relationships",
                 Jason.encode!(%{
                   "data" => [
                     %{"id" => "1", "type" => "user"},
                     %{"id" => "2", "type" => "user"}
                   ]
                 })
               )
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end

    test "processes empty keys" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{id: "1", type: "user"}
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
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
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end

    test "processes empty attributes" do
      assert %Conn{
               private: %{
                 jsonapi: %JSONAPI{
                   document: %Document{
                     data: %ResourceObject{id: "1", type: "user"}
                   }
                 }
               }
             } =
               Plug.Test.conn(
                 "POST",
                 "/",
                 Jason.encode!(%{
                   "data" => %{
                     "id" => "1",
                     "type" => "user"
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> UserViewPlug.call([])
    end
  end

  describe "query parameters" do
    test "parse_sort/2 turns sorts into valid ecto sorts" do
      assert %Conn{private: %{jsonapi: %JSONAPI{sort: [asc: :body, asc: :title]}}} =
               Plug.Test.conn("GET", "/?sort=body,title")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{sort: [asc: :body]}}} =
               Plug.Test.conn("GET", "/?sort=body")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{sort: [desc: :body]}}} =
               Plug.Test.conn("GET", "/?sort=-body")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{sort: [asc: :body, desc: :title]}}} =
               Plug.Test.conn("GET", "/?sort=body,-title")
               |> MyPostViewPlug.call([])
    end

    test "parse_sort/2 raises on invalid sorts" do
      assert_raise InvalidQuery, "invalid parameter sort=name for type my-type", fn ->
        Plug.Test.conn("GET", "/?sort=name")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_filter/2 stores filters" do
      assert %Conn{private: %{jsonapi: %JSONAPI{filter: %{"name" => "jason"}}}} =
               Plug.Test.conn("GET", "/?filter[name]=jason")
               |> MyPostViewPlug.call([])
    end

    test "parse_filter/2 raises on invalid filters" do
      assert_raise InvalidQuery, "invalid parameter filter=invalid for type my-type", fn ->
        Plug.Test.conn("GET", "/?filter=invalid")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_include/2 turns an include string into a keyword list" do
      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=author,comments.user")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author])
      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=author")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=comments,author")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:comments])
      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=comments.user")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=best_friends")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:best_friends])

      assert %Conn{private: %{jsonapi: %JSONAPI{include: include}}} =
               Plug.Test.conn("GET", "/?include=author.top-posts,author.company")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author, :top_posts])
      assert [] = get_in(include, [:author, :company])
    end

    test "parse_include/2 errors with invalid includes" do
      assert_raise InvalidQuery, "invalid parameter include=user for type my-type", fn ->
        Plug.Test.conn("GET", "/?include=user,comments.author")
        |> MyPostViewPlug.call([])
      end

      assert_raise InvalidQuery,
                   "invalid parameter include=author for type comment",
                   fn ->
                     Plug.Test.conn("GET", "/?include=comments.author")
                     |> MyPostViewPlug.call([])
                   end

      assert_raise InvalidQuery,
                   "invalid parameter include=author.user for type comment",
                   fn ->
                     Plug.Test.conn("GET", "/?include=comments.author.user")
                     |> MyPostViewPlug.call([])
                   end

      assert_raise InvalidQuery, "invalid parameter include=fake_rel for type my-type", fn ->
        Plug.Test.conn("GET", "/?include=fake-rel")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      assert %Conn{private: %{jsonapi: %JSONAPI{fields: %{"my-type" => [:text]}}}} =
               Plug.Test.conn("GET", "/?fields[my-type]=text")
               |> MyPostViewPlug.call([])
    end

    test "parse_fields/2 raises on invalid parsing" do
      assert_raise InvalidQuery, "invalid parameter fields=blag for type my-type", fn ->
        Plug.Test.conn("GET", "/?fields[my-type]=blag")
        |> MyPostViewPlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter fields=username for type my-type", fn ->
        Plug.Test.conn("GET", "/?fields[my-type]=username")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_page/2 turns a fields map into a map of pagination values" do
      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{}}}} =
               Plug.Test.conn("GET", "/")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{"cursor" => "cursor"}}}} =
               Plug.Test.conn("GET", "/?page[cursor]=cursor")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{"limit" => "1"}}}} =
               Plug.Test.conn("GET", "/?page[limit]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{"offset" => "1"}}}} =
               Plug.Test.conn("GET", "/?page[offset]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{"page" => "1"}}}} =
               Plug.Test.conn("GET", "/?page[page]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi: %JSONAPI{page: %{"size" => "1"}}}} =
               Plug.Test.conn("GET", "/?page[size]=1")
               |> MyPostViewPlug.call([])
    end
  end
end
