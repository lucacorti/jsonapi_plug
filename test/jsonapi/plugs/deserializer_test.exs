defmodule JSONAPI.DeserializerTest do
  use ExUnit.Case
  use Plug.Test

  defmodule ExamplePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Deserializer
    plug :return

    def return(conn, _opts) do
      send_resp(conn, 200, "success")
    end
  end

  test "Ignores bodyless requests" do
    conn =
      Plug.Test.conn("GET", "/")
      |> put_req_header("content-type", JSONAPI.mime_type())
      |> put_req_header("accept", JSONAPI.mime_type())

    result = ExamplePlug.call(conn, [])
    assert result.params == %{}
  end

  test "ignores non-jsonapi.org format params" do
    req_body = Jason.encode!(%{"some-nonsense" => "yup"})

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", JSONAPI.mime_type())
      |> put_req_header("accept", JSONAPI.mime_type())

    result = ExamplePlug.call(conn, [])
    assert result.params == %{"some-nonsense" => "yup"}
  end

  test "works with basic list of data" do
    req_body =
      Jason.encode!(%{
        "data" => [
          %{"id" => "1", "type" => "car"},
          %{"id" => "2", "type" => "car"}
        ]
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", JSONAPI.mime_type())
      |> put_req_header("accept", JSONAPI.mime_type())

    result = ExamplePlug.call(conn, [])

    assert result.params == [
             %{"id" => "1", "type" => "car"},
             %{"id" => "2", "type" => "car"}
           ]
  end

  test "deserializes attribute key names" do
    req_body =
      Jason.encode!(%{
        "data" => %{
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

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", JSONAPI.mime_type())
      |> put_req_header("accept", JSONAPI.mime_type())

    result = ExamplePlug.call(conn, [])
    assert result.params["some-nonsense"] == true
    assert result.params["some-map"]["nested-key"] == true
    assert result.params["baz-id"] == "2"

    # Preserves query params
    assert result.params["filter"]["dog-breed"] == "Corgi"
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

      conn =
        Plug.Test.conn("POST", "/", req_body)
        |> put_req_header("content-type", JSONAPI.mime_type())
        |> put_req_header("accept", JSONAPI.mime_type())

      result = ExampleUnderscorePlug.call(conn, [])
      assert result.params["some_nonsense"] == true
      assert result.params["some_map"]["nested_key"] == true
      assert result.params["baz_id"] == "2"
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

      conn =
        Plug.Test.conn("POST", "/", req_body)
        |> put_req_header("content-type", JSONAPI.mime_type())
        |> put_req_header("accept", JSONAPI.mime_type())

      result = ExampleCamelCasePlug.call(conn, [])
      assert result.params["someNonsense"] == true
      assert result.params["someMap"]["nested_key"] == true
      assert result.params["bazId"] == "2"
    end
  end

  test "converts attributes and relationships to flattened data structure" do
    incoming = %{
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
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => "2",
             "boo-id" => nil
           }
  end

  test "converts to many relationship" do
    incoming = %{
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

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => ["2", "3"]
           }
  end

  test "converts polymorphic" do
    incoming = %{
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

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => "2",
             "yooper-id" => "3"
           }
  end

  test "processes single includes" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "name" => "Jerome"
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
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "friend" => [
               %{
                 "name" => "Tara",
                 "id" => "234",
                 "type" => "friend"
               }
             ],
             "id" => "1",
             "type" => "user",
             "name" => "Jerome"
           }
  end

  test "processes has many includes" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "name" => "Jerome"
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
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "friend" => [
               %{
                 "name" => "Wild Bill",
                 "id" => "0012",
                 "type" => "friend"
               },
               %{
                 "name" => "Tara",
                 "id" => "234",
                 "type" => "friend",
                 "baz-id" => "2",
                 "boo-id" => nil
               }
             ],
             "organization" => [
               %{
                 "title" => "Sr",
                 "id" => "456",
                 "type" => "organization"
               }
             ],
             "id" => "1",
             "type" => "user",
             "name" => "Jerome"
           }
  end

  test "processes simple array of data" do
    incoming = %{
      "data" => [
        %{"id" => "1", "type" => "user"},
        %{"id" => "2", "type" => "user"}
      ]
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == [
             %{"id" => "1", "type" => "user"},
             %{"id" => "2", "type" => "user"}
           ]
  end

  test "processes empty keys" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => nil
      },
      "relationships" => nil,
      "included" => nil
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user"
           }
  end

  test "processes empty data" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user"
      }
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user"
           }
  end

  test "processes nil data" do
    incoming = %{
      "data" => nil
    }

    result = JSONAPI.Deserializer.process(incoming)

    assert result == nil
  end
end
