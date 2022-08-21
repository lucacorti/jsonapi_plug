defmodule JSONAPIPlug.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPIPlug.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject,
    Exceptions.InvalidQuery
  }

  alias JSONAPIPlug.TestSupport.APIs.DefaultAPI
  alias JSONAPIPlug.TestSupport.Views.{CarView, MyPostView, UserView}
  alias Plug.Conn

  defmodule CarViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, view: CarView
  end

  defmodule UserViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, view: UserView
  end

  defmodule MyPostViewPlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPIPlug.Plug, api: DefaultAPI, view: MyPostView
  end

  describe "request body" do
    test "Ignores bodyless requests" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{data: nil}
                 }
               }
             } =
               conn(:get, "/")
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> CarViewPlug.call([])
    end

    test "ignores non-jsonapi.org format params" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{data: %ResourceObject{id: "1", type: "car"}}
                 }
               }
             } =
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
               |> CarViewPlug.call([])
    end

    test "works with basic list of data" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{
                     data: [%ResourceObject{id: "1"}, %ResourceObject{id: "2"}]
                   }
                 }
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
               |> CarViewPlug.call([])
    end

    test "deserializes attribute key names" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
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
               |> CarViewPlug.call([])
    end

    test "converts to many relationship" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
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
               |> UserViewPlug.call([])
    end

    test "converts polymorphic" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
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
               |> UserViewPlug.call([])
    end

    test "processes single includes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{
                     data: %ResourceObject{
                       id: "1",
                       type: "user",
                       attributes: %{"firstName" => "Jerome"},
                       relationships: %{
                         "company" => %RelationshipObject{
                           data: %ResourceIdentifierObject{id: "234", type: "company"}
                         }
                       }
                     },
                     included: [
                       %ResourceObject{
                         id: "234",
                         type: "company",
                         attributes: %{"name" => "Tara"}
                       }
                     ]
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
               |> UserViewPlug.call([])
    end

    test "processes has many includes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
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
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{
                     data: [
                       %ResourceObject{id: "1", type: "user"},
                       %ResourceObject{id: "2", type: "user"}
                     ]
                   }
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
               |> UserViewPlug.call([])
    end

    test "processes empty keys" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{
                     data: %ResourceObject{id: "1", type: "user"}
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
                     "attributes" => nil
                   },
                   "relationships" => nil,
                   "included" => nil
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserViewPlug.call([])
    end

    test "processes empty attributes" do
      assert %Conn{
               private: %{
                 jsonapi_plug: %JSONAPIPlug{
                   document: %Document{
                     data: %ResourceObject{id: "1", type: "user"}
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
                     "type" => "user"
                   }
                 })
               )
               |> put_req_header("content-type", JSONAPIPlug.mime_type())
               |> put_req_header("accept", JSONAPIPlug.mime_type())
               |> UserViewPlug.call([])
    end
  end

  describe "query parameters" do
    test "parse_sort/2 turns sorts into valid ecto sorts" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, asc: :title]}}} =
               conn(:get, "/?sort=body,title")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body]}}} =
               conn(:get, "/?sort=body")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [desc: :body]}}} =
               conn(:get, "/?sort=-body")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{sort: [asc: :body, desc: :title]}}} =
               conn(:get, "/?sort=body,-title")
               |> MyPostViewPlug.call([])
    end

    test "parse_sort/2 raises on invalid sorts" do
      assert_raise InvalidQuery, "invalid parameter sort=name for type my-type", fn ->
        conn(:get, "/?sort=name")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_filter/2 stores filters" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{filter: %{"name" => "jason"}}}} =
               conn(:get, "/?filter[name]=jason")
               |> MyPostViewPlug.call([])
    end

    test "parse_include/2 turns an include string into a keyword list" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author,comments.user")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author])
      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=comments,author")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:comments])
      assert [] = get_in(include, [:author])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=comments.user")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:comments, :user])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=best_friends")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:best_friends])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{include: include}}} =
               conn(:get, "/?include=author.top-posts,author.company")
               |> MyPostViewPlug.call([])

      assert [] = get_in(include, [:author, :top_posts])
      assert [] = get_in(include, [:author, :company])
    end

    test "parse_include/2 errors with invalid includes" do
      assert_raise InvalidQuery, "invalid parameter include=user for type my-type", fn ->
        conn(:get, "/?include=user,comments.author")
        |> MyPostViewPlug.call([])
      end

      assert_raise InvalidQuery,
                   "invalid parameter include=author for type comment",
                   fn ->
                     conn(:get, "/?include=comments.author")
                     |> MyPostViewPlug.call([])
                   end

      assert_raise InvalidQuery,
                   "invalid parameter include=author.user for type comment",
                   fn ->
                     conn(:get, "/?include=comments.author.user")
                     |> MyPostViewPlug.call([])
                   end

      assert_raise InvalidQuery, "invalid parameter include=fake_rel for type my-type", fn ->
        conn(:get, "/?include=fake-rel")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_fields/2 turns a fields map into a map of validated fields" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{fields: %{"my-type" => [:text]}}}} =
               conn(:get, "/?fields[my-type]=text")
               |> MyPostViewPlug.call([])
    end

    test "parse_fields/2 raises on invalid parsing" do
      assert_raise InvalidQuery, "invalid parameter fields=blag for type my-type", fn ->
        conn(:get, "/?fields[my-type]=blag")
        |> MyPostViewPlug.call([])
      end

      assert_raise InvalidQuery, "invalid parameter fields=username for type my-type", fn ->
        conn(:get, "/?fields[my-type]=username")
        |> MyPostViewPlug.call([])
      end
    end

    test "parse_page/2 turns a fields map into a map of pagination values" do
      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: nil}}} =
               conn(:get, "/")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"cursor" => "cursor"}}}} =
               conn(:get, "/?page[cursor]=cursor")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"limit" => "1"}}}} =
               conn(:get, "/?page[limit]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"offset" => "1"}}}} =
               conn(:get, "/?page[offset]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"page" => "1"}}}} =
               conn(:get, "/?page[page]=1")
               |> MyPostViewPlug.call([])

      assert %Conn{private: %{jsonapi_plug: %JSONAPIPlug{page: %{"size" => "1"}}}} =
               conn(:get, "/?page[size]=1")
               |> MyPostViewPlug.call([])
    end
  end
end
