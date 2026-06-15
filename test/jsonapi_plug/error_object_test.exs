defmodule JSONAPIPlug.Document.ErrorObjectTest do
  use ExUnit.Case, async: true

  alias JSONAPIPlug.Document.ErrorObject

  describe "ErrorObject links with type member" do
    test "serializes links with about key" do
      error = %ErrorObject{
        status: "404",
        links: %{"about" => "https://example.com/help"}
      }

      encoded = Jason.decode!(Jason.encode!(error))
      assert encoded["links"]["about"] == "https://example.com/help"
    end

    test "serializes links with type key" do
      error = %ErrorObject{
        status: "400",
        links: %{"type" => "https://example.com/errors/bad-request"}
      }

      encoded = Jason.decode!(Jason.encode!(error))
      assert encoded["links"]["type"] == "https://example.com/errors/bad-request"
    end

    test "serializes links with both about and type keys" do
      error = %ErrorObject{
        status: "400",
        links: %{
          "about" => "https://example.com/help",
          "type" => "https://example.com/errors/bad-request"
        }
      }

      encoded = Jason.decode!(Jason.encode!(error))
      assert encoded["links"]["about"] == "https://example.com/help"
      assert encoded["links"]["type"] == "https://example.com/errors/bad-request"
    end

    test "deserializes error with links containing type" do
      data = %{
        "status" => "400",
        "links" => %{
          "about" => "https://example.com/help",
          "type" => "https://example.com/errors/bad-request"
        }
      }

      error = ErrorObject.deserialize(data)
      assert error.links["about"] == "https://example.com/help"
      assert error.links["type"] == "https://example.com/errors/bad-request"
    end

    test "omits links when nil" do
      error = %ErrorObject{status: "500"}
      encoded = Jason.decode!(Jason.encode!(error))
      refute Map.has_key?(encoded, "links")
    end
  end
end
