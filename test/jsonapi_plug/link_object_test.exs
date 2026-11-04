defmodule JSONAPIPlug.Document.LinkObjectTest do
  use ExUnit.Case, async: true

  alias JSONAPIPlug.Document.LinkObject

  describe "LinkObject encoding" do
    test "encodes href as string link" do
      link = "https://example.com/articles/1"
      assert Jason.encode!(link) == ~s("https://example.com/articles/1")
    end

    test "encodes link object with href only" do
      link = %LinkObject{href: "https://example.com/articles/1"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["href"] == "https://example.com/articles/1"
    end

    test "encodes rel when present" do
      link = %LinkObject{href: "https://example.com", rel: "self"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["rel"] == "self"
    end

    test "omits rel when nil" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      refute Map.has_key?(encoded, "rel")
    end

    test "encodes describedby when present" do
      link = %LinkObject{href: "https://example.com", describedby: "https://example.com/schema"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["describedby"] == "https://example.com/schema"
    end

    test "omits describedby when nil" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      refute Map.has_key?(encoded, "describedby")
    end

    test "encodes title when present" do
      link = %LinkObject{href: "https://example.com", title: "Comments"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["title"] == "Comments"
    end

    test "omits title when nil" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      refute Map.has_key?(encoded, "title")
    end

    test "encodes type when present" do
      link = %LinkObject{href: "https://example.com", type: "application/vnd.api+json"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["type"] == "application/vnd.api+json"
    end

    test "omits type when nil" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      refute Map.has_key?(encoded, "type")
    end

    test "encodes hreflang as string when present" do
      link = %LinkObject{href: "https://example.com", hreflang: "en"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["hreflang"] == "en"
    end

    test "encodes hreflang as list when present" do
      link = %LinkObject{href: "https://example.com", hreflang: ["en", "fr"]}
      encoded = Jason.decode!(Jason.encode!(link))
      assert encoded["hreflang"] == ["en", "fr"]
    end

    test "omits hreflang when nil" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      refute Map.has_key?(encoded, "hreflang")
    end

    test "omits all nil fields" do
      link = %LinkObject{href: "https://example.com"}
      encoded = Jason.decode!(Jason.encode!(link))
      assert Map.keys(encoded) == ["href"]
    end
  end

  describe "LinkObject deserialization" do
    test "deserializes string link" do
      assert LinkObject.deserialize("https://example.com") == "https://example.com"
    end

    test "deserializes link object with all 1.1 fields" do
      data = %{
        "href" => "https://example.com",
        "rel" => "self",
        "describedby" => "https://example.com/schema",
        "title" => "Comments",
        "type" => "application/vnd.api+json",
        "hreflang" => "en"
      }

      link = LinkObject.deserialize(data)
      assert link.href == "https://example.com"
      assert link.rel == "self"
      assert link.describedby == "https://example.com/schema"
      assert link.title == "Comments"
      assert link.type == "application/vnd.api+json"
      assert link.hreflang == "en"
    end
  end

  describe "describedby in top-level document links" do
    test "document with describedby link is serialized" do
      doc = %JSONAPIPlug.Document{
        data: nil,
        links: %{describedby: "https://example.com/openapi"}
      }

      encoded = Jason.decode!(Jason.encode!(doc))
      assert encoded["links"]["describedby"] == "https://example.com/openapi"
    end
  end
end
