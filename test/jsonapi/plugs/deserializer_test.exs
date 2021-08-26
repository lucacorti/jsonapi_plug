defmodule JSONAPI.DeserializerTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.Document
  alias JSONAPI.QueryParser
  alias JSONAPI.TestSupport.Resources.{Car, User}
  alias JSONAPI.TestSupport.Views.{CarView, UserView}
  alias Plug.Conn

  defmodule ExamplePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Deserializer
  end

  test "Ignores bodyless requests" do
    assert %Conn{assigns: %{jsonapi: %JSONAPI{document: %Document{data: nil}}}} =
             Plug.Test.conn("GET", "/")
             |> put_req_header("content-type", JSONAPI.mime_type())
             |> put_req_header("accept", JSONAPI.mime_type())
             |> QueryParser.call(%JSONAPI{view: UserView})
             |> ExamplePlug.call([])
  end

  test "ignores non-jsonapi.org format params" do
    req_body = Jason.encode!(%{"some-nonsense" => "yup"})

    assert %Conn{assigns: %{jsonapi: %JSONAPI{document: %Document{data: nil}}}} =
             Plug.Test.conn("POST", "/", req_body)
             |> put_req_header("content-type", JSONAPI.mime_type())
             |> put_req_header("accept", JSONAPI.mime_type())
             |> QueryParser.call(%JSONAPI{view: CarView})
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
             assigns: %{
               jsonapi: %JSONAPI{
                 document: %Document{
                   data: [
                     %Car{id: "1"},
                     %Car{id: "2"}
                   ]
                 }
               }
             }
           } =
             Plug.Test.conn("POST", "/", req_body)
             |> put_req_header("content-type", JSONAPI.mime_type())
             |> put_req_header("accept", JSONAPI.mime_type())
             |> QueryParser.call(%JSONAPI{view: CarView})
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

    assert %Conn{assigns: %{jsonapi: %JSONAPI{document: %Document{data: %Car{id: "1"}}}}} =
             Plug.Test.conn("POST", "/", req_body)
             |> put_req_header("content-type", JSONAPI.mime_type())
             |> put_req_header("accept", JSONAPI.mime_type())
             |> QueryParser.call(%JSONAPI{view: CarView})
             |> ExamplePlug.call([])
  end

  describe "underscore" do
    defmodule ExampleUnderscorePlug do
      use Plug.Builder
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer
      plug JSONAPI.UnderscoreParameters

      plug :return

      def return(conn, _opts) do
        send_resp(conn, 200, "success")
      end
    end

    test "deserializes attribute key names and underscores them" do
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

      assert %Conn{assigns: %{jsonapi: %JSONAPI{document: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> QueryParser.call(%JSONAPI{view: CarView})
               |> ExampleUnderscorePlug.call([])
    end
  end

  describe "camelize" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :camelize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    defmodule ExampleCamelCasePlug do
      use Plug.Builder
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer

      plug :return

      def return(conn, _opts) do
        send_resp(conn, 200, "success")
      end
    end

    test "deserializes attribute key names and underscores them" do
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

      assert %Conn{assigns: %{jsonapi: %JSONAPI{document: %Document{data: %Car{id: "1"}}}}} =
               Plug.Test.conn("POST", "/", req_body)
               |> put_req_header("content-type", JSONAPI.mime_type())
               |> put_req_header("accept", JSONAPI.mime_type())
               |> QueryParser.call(%JSONAPI{view: CarView})
               |> ExampleCamelCasePlug.call([])
    end
  end

  test "converts attributes and relationships to flattened data structure" do
    assert %Document{data: %User{id: "1"}} =
             Document.deserialize(UserView, %{
               "data" => %{
                 "id" => "1",
                 "type" => "user",
                 "attributes" => %{
                   "foo-bar" => true
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
             })
  end

  test "converts to many relationship" do
    assert %Document{data: %User{id: "1"}} =
             Document.deserialize(UserView, %{
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
  end

  test "converts polymorphic" do
    assert %Document{data: %User{id: "1"}} =
             Document.deserialize(UserView, %{
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
  end

  test "processes single includes" do
    assert %Document{data: %User{id: "1", first_name: "Jerome"}} =
             Document.deserialize(UserView, %{
               "data" => %{
                 "id" => "1",
                 "type" => "user",
                 "attributes" => %{
                   "first_name" => "Jerome"
                 }
               },
               "included" => [
                 %{
                   "data" => %{
                     "attributes" => %{
                       "name" => "Tara"
                     },
                     "id" => "234",
                     "type" => "friend"
                   }
                 }
               ]
             })
  end

  test "processes has many includes" do
    assert %Document{data: %User{id: "1", first_name: "Jerome"}} =
             Document.deserialize(UserView, %{
               "data" => %{
                 "id" => "1",
                 "type" => "user",
                 "attributes" => %{
                   "first_name" => "Jerome"
                 }
               },
               "included" => [
                 %{
                   "data" => %{
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
                   }
                 },
                 %{
                   "data" => %{
                     "attributes" => %{
                       "name" => "Wild Bill"
                     },
                     "id" => "0012",
                     "type" => "friend"
                   }
                 },
                 %{
                   "data" => %{
                     "attributes" => %{
                       "title" => "Sr"
                     },
                     "id" => "456",
                     "type" => "organization"
                   }
                 }
               ]
             })
  end

  test "processes simple array of data" do
    assert %Document{
             data: [
               %User{id: "1"},
               %User{id: "2"}
             ]
           } =
             Document.deserialize(UserView, %{
               "data" => [
                 %{"id" => "1", "type" => "user"},
                 %{"id" => "2", "type" => "user"}
               ]
             })
  end

  test "processes empty keys" do
    assert %Document{data: %User{id: "1"}} =
             Document.deserialize(UserView, %{
               "data" => %{
                 "id" => "1",
                 "type" => "user",
                 "attributes" => nil
               },
               "relationships" => nil,
               "included" => nil
             })
  end

  test "processes empty data" do
    assert %Document{data: %User{id: "1"}} =
             Document.deserialize(UserView, %{
               "data" => %{
                 "id" => "1",
                 "type" => "user"
               }
             })
  end

  test "processes nil data" do
    assert %Document{data: nil} = Document.deserialize(UserView, %{"data" => nil})
  end
end
