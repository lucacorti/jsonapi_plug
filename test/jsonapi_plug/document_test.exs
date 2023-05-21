defmodule JSONAPIPlug.DocumentTest do
  use ExUnit.Case, async: false

  alias JSONAPIPlug.{
    Document,
    Document.RelationshipObject,
    Document.ResourceIdentifierObject,
    Document.ResourceObject
  }

  describe "Document serialization" do
    test "serialize nil data works" do
      assert %{"data" => nil} = Jason.encode!(%Document{data: nil}) |> Jason.decode!()
      assert %{"data" => []} = Jason.encode!(%Document{data: []}) |> Jason.decode!()
    end

    test "serialize includes meta as top level member" do
      assert %{"data" => nil, "meta" => %{"total_pages" => 10}} =
               %Document{meta: %{"total_pages" => 10}}
               |> Jason.encode!()
               |> Jason.decode!()
    end

    test "serialize includes meta only if provided" do
      assert %{"data" => %{"meta" => %{"meta_text" => "meta_Hello"}}} =
               %Document{
                 data: %ResourceObject{
                   id: "1",
                   attributes: %{"text" => "Hello"},
                   meta: %{"meta_text" => "meta_Hello"}
                 }
               }
               |> Jason.encode!()
               |> Jason.decode!()

      assert %{"data" => %{"id" => "1", "type" => "comment"}, "meta" => %{"cool" => true}} =
               %Document{
                 data: %ResourceObject{id: "1", type: "comment"},
                 meta: %{"cool" => true}
               }
               |> Jason.encode!()
               |> Jason.decode!()
    end

    test "serialize handles singular objects" do
      post = %ResourceObject{
        id: "1",
        type: "post",
        attributes: %{
          "text" => "Hello",
          "body" => "Hello world"
        },
        relationships: %{
          "author" => %RelationshipObject{
            data: %ResourceIdentifierObject{id: "2", type: "user"}
          },
          "bestComments" => [
            %RelationshipObject{
              data: %ResourceIdentifierObject{id: "5", type: "comment"}
            },
            %RelationshipObject{
              data: %ResourceIdentifierObject{id: "6", type: "comment"}
            }
          ]
        }
      }

      included = [
        %ResourceObject{
          id: "2",
          type: "user",
          attributes: %{"username" => "jason"}
        },
        %ResourceObject{
          id: "4",
          type: "user",
          attributes: %{"username" => "jack"}
        },
        %ResourceObject{
          id: "5",
          type: "comment",
          attributes: %{"text" => "greatest comment ever"},
          relationships: %{
            "author" => %RelationshipObject{
              data: %ResourceIdentifierObject{id: "4", type: "user"}
            }
          }
        },
        %ResourceObject{
          id: "6",
          type: "comment",
          attributes: %{"text" => "not so great"},
          relationships: %{
            "author" => %RelationshipObject{
              data: %ResourceIdentifierObject{id: "2", type: "user"}
            }
          }
        }
      ]

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => type,
                 "attributes" => %{"text" => text, "body" => body},
                 "relationships" => relationships
               },
               "included" => included
             } =
               %Document{data: post, included: included}
               |> Jason.encode!()
               |> Jason.decode!()

      assert ^id = post.id
      assert ^type = post.type
      assert ^text = post.attributes["text"]
      assert ^body = post.attributes["body"]
      assert map_size(relationships) == 2
      assert Enum.count(included) == 4
    end

    test "serialize handles a list" do
      post = %ResourceObject{
        id: "1",
        type: "post",
        attributes: %{
          "text" => "Hello",
          "body" => "Hello world"
        },
        relationships: %{
          "author" => %RelationshipObject{
            data: %ResourceIdentifierObject{id: "2", type: "user"}
          },
          "bestComments" => [
            %RelationshipObject{
              data: %ResourceIdentifierObject{id: "5", type: "comment"}
            },
            %RelationshipObject{
              data: %ResourceIdentifierObject{id: "6", type: "comment"}
            }
          ]
        }
      }

      included = [
        %ResourceObject{
          id: "2",
          type: "user",
          attributes: %{"username" => "jason"}
        },
        %ResourceObject{
          id: "4",
          type: "user",
          attributes: %{"username" => "jack"}
        },
        %ResourceObject{
          id: "5",
          type: "comment",
          attributes: %{"text" => "greatest comment ever"},
          relationships: %{
            "author" => %RelationshipObject{
              data: %ResourceIdentifierObject{id: "4", type: "user"}
            }
          }
        },
        %ResourceObject{
          id: "6",
          type: "comment",
          attributes: %{"text" => "not so great"},
          relationships: %{
            "author" => %RelationshipObject{
              data: %ResourceIdentifierObject{id: "2", type: "user"}
            }
          }
        }
      ]

      assert %{
               "data" => data,
               "included" => included
             } =
               %Document{data: [post, post, post], included: included}
               |> Jason.encode!()
               |> Jason.decode!()

      assert Enum.count(data) == 3
      assert Enum.count(included) == 4

      Enum.each(data, fn %{
                           "id" => id,
                           "type" => type,
                           "attributes" => attributes,
                           "relationships" => relationships
                         } ->
        assert ^id = post.id
        assert ^type = post.type
        assert attributes["text"] == post.attributes["text"]
        assert attributes["body"] == post.attributes["body"]
        assert map_size(relationships) == 2
      end)
    end

    test "serialize handles an empty relationship" do
      post = %ResourceObject{
        id: "1",
        type: "post",
        attributes: %{
          "text" => "Hello",
          "body" => "Hello world"
        },
        relationships: %{
          "author" => %RelationshipObject{
            data: %ResourceIdentifierObject{id: "2", type: "user"}
          },
          "bestComments" => []
        }
      }

      included = [
        %ResourceObject{
          id: "2",
          type: "user",
          attributes: %{"username" => "jason"}
        }
      ]

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => type,
                 "attributes" => attributes,
                 "relationships" => relationships
               },
               "included" => included
             } =
               %Document{data: post, included: included}
               |> Jason.encode!()
               |> Jason.decode!()

      assert ^id = post.id
      assert ^type = post.type
      assert attributes["text"] == post.attributes["text"]
      assert attributes["body"] == post.attributes["body"]
      assert map_size(relationships) == 2

      assert [] = relationships["bestComments"]

      assert Enum.count(included) == 1
    end

    test "serialize handles a nil relationship" do
      post = %ResourceObject{
        id: "1",
        type: "post",
        attributes: %{
          "text" => "Hello",
          "body" => "Hello world"
        },
        relationships: %{
          "author" => %RelationshipObject{
            data: %ResourceIdentifierObject{id: "2", type: "user"}
          },
          "bestComments" => nil
        }
      }

      included = [
        %ResourceObject{
          id: "2",
          type: "user",
          attributes: %{"username" => "jason"}
        }
      ]

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => type,
                 "attributes" => attributes,
                 "relationships" => relationships
               },
               "included" => included
             } =
               %Document{data: post, included: included}
               |> Jason.encode!()
               |> Jason.decode!()

      assert ^id = post.id
      assert ^type = post.type
      assert attributes["text"] == post.attributes["text"]
      assert attributes["body"] == post.attributes["body"]
      assert map_size(relationships) == 2
      assert Enum.count(included) == 1
    end
  end

  describe "document deserialization" do
    test "deserialize empty document" do
      assert %Document{data: nil} = Document.parse(%{})
    end

    test "deserialize null data" do
      assert %Document{data: nil} = Document.parse(%{"data" => nil})
    end

    test "deserialize empty list" do
      assert %Document{data: []} = Document.parse(%{"data" => []})
    end

    test "deserialize single resource object" do
      assert %Document{data: %ResourceObject{id: "1", type: "post"}} =
               Document.parse(%{"data" => %{"type" => "post", "id" => "1"}})
    end

    test "deserialize one element resource list" do
      assert %Document{data: [%ResourceObject{id: "1", type: "post"}]} =
               Document.parse(%{"data" => [%{"type" => "post", "id" => "1"}]})
    end

    test "deserialize multiple element resource list" do
      assert %Document{
               data: [
                 %ResourceObject{id: "1", type: "post"},
                 %ResourceObject{id: "2", type: "post"},
                 %ResourceObject{id: "3", type: "post"}
               ]
             } =
               Document.parse(%{
                 "data" => [
                   %{"type" => "post", "id" => "1"},
                   %{"type" => "post", "id" => "2"},
                   %{"type" => "post", "id" => "3"}
                 ]
               })
    end

    test "deserialize resource with included relationship" do
      assert %Document{
               data: %ResourceObject{
                 id: "1",
                 relationships: %{
                   "author" => %JSONAPIPlug.Document.RelationshipObject{
                     data: %JSONAPIPlug.Document.ResourceIdentifierObject{
                       id: "1",
                       type: "user"
                     }
                   },
                   "bestComments" => [
                     %JSONAPIPlug.Document.RelationshipObject{
                       data: %JSONAPIPlug.Document.ResourceIdentifierObject{
                         id: "1",
                         type: "comment"
                       }
                     }
                   ]
                 }
               },
               included: [
                 %ResourceObject{id: "1", type: "user", attributes: %{"firstName" => "Luca"}},
                 %ResourceObject{id: "1", type: "comment", attributes: %{"text" => "Hello"}}
               ]
             } =
               Document.parse(%{
                 "data" => %{
                   "type" => "post",
                   "id" => "1",
                   "relationships" => %{
                     "author" => %{"data" => %{"id" => "1", "type" => "user"}},
                     "bestComments" => [%{"data" => %{"id" => "1", "type" => "comment"}}]
                   }
                 },
                 "included" => [
                   %{
                     "type" => "user",
                     "id" => "1",
                     "attributes" => %{"firstName" => "Luca"}
                   },
                   %{
                     "type" => "comment",
                     "id" => "1",
                     "attributes" => %{"text" => "Hello"}
                   }
                 ]
               })
    end
  end

  test "deserialize resource list with nested included relationship" do
    assert %Document{
             data: [
               %ResourceObject{
                 id: "1",
                 type: "post",
                 relationships: %{
                   "author" => %RelationshipObject{
                     data: %ResourceIdentifierObject{id: "1", type: "user"}
                   }
                 }
               },
               %ResourceObject{
                 id: "2",
                 type: "post",
                 relationships: %{
                   "author" => %RelationshipObject{
                     data: %ResourceIdentifierObject{id: "1", type: "user"}
                   }
                 }
               },
               %ResourceObject{
                 id: "3",
                 type: "post",
                 relationships: %{
                   "author" => %RelationshipObject{
                     data: %ResourceIdentifierObject{id: "1", type: "user"}
                   }
                 }
               }
             ],
             included: [
               %ResourceObject{
                 id: "1",
                 type: "user",
                 relationships: %{
                   "company" => %RelationshipObject{
                     data: %ResourceIdentifierObject{id: "1", type: "company"}
                   }
                 }
               },
               %ResourceObject{id: "1", type: "company"}
             ]
           } =
             Document.parse(%{
               "data" => [
                 %{
                   "type" => "post",
                   "id" => "1",
                   "relationships" => %{
                     "author" => %{"data" => %{"id" => "1", "type" => "user"}}
                   }
                 },
                 %{
                   "type" => "post",
                   "id" => "2",
                   "relationships" => %{
                     "author" => %{"data" => %{"id" => "1", "type" => "user"}}
                   }
                 },
                 %{
                   "type" => "post",
                   "id" => "3",
                   "relationships" => %{
                     "author" => %{"data" => %{"id" => "1", "type" => "user"}}
                   }
                 }
               ],
               "included" => [
                 %{
                   "type" => "user",
                   "id" => "1",
                   "attributes" => %{},
                   "relationships" => %{
                     "company" => %{"data" => %{"id" => "1", "type" => "company"}}
                   }
                 },
                 %{
                   "type" => "company",
                   "id" => "1",
                   "attributes" => %{}
                 }
               ]
             })
  end
end
