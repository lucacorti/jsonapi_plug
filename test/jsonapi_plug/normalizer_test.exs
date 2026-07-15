defmodule JSONAPIPlug.NormalizerTest do
  use ExUnit.Case
  import Plug.Test

  alias JSONAPIPlug.{Document, Document.ResourceObject}
  alias JSONAPIPlug.TestSupport.Plugs.UnderscoringPostPlug
  alias JSONAPIPlug.TestSupport.Resources.{Comment, Company, Industry, Post, Tag, User}

  defp included_with_id(%Document{included: included}, type, id),
    do: Enum.filter(included, &(&1.type == type and &1.id == id))

  describe "normalize included deduplication" do
    test "collapses a resource reached via multiple include paths into a single object" do
      conn =
        conn(:get, "/?include=author.company,best_comments.user") |> UnderscoringPostPlug.call([])

      author = %User{id: 1, first_name: "Ada", company: %Company{id: 9, name: "Initech"}}
      comment = %Comment{id: 5, body: "hi", user: %User{id: 1, first_name: "Ada"}}
      post = %Post{id: 1, text: "Hello", author: author, best_comments: [comment]}

      document = JSONAPIPlug.render(conn, post)

      assert [%ResourceObject{relationships: relationships}] =
               included_with_id(document, "user", "1")

      assert Map.has_key?(relationships, "company")
      assert [%ResourceObject{}] = included_with_id(document, "company", "9")
    end

    test "leaves a document without duplicate resources untouched" do
      conn = conn(:get, "/?include=author,best_comments") |> UnderscoringPostPlug.call([])

      post = %Post{
        id: 1,
        text: "Hello",
        author: %User{id: 1, first_name: "Ada"},
        best_comments: [%Comment{id: 5, body: "hi"}]
      }

      assert %Document{included: included} = JSONAPIPlug.render(conn, post)

      assert included |> Enum.map(&{&1.type, &1.id}) |> Enum.sort() == [
               {"comment", "5"},
               {"user", "1"}
             ]
    end

    test "merges to-many relationship identifiers into one" do
      conn =
        conn(:get, "/?include=author.company.industry.tags,other_user.company.industry.tags")
        |> UnderscoringPostPlug.call([])

      industry_a = %Industry{id: 7, name: "Tech", tags: [%Tag{id: 100, name: "a"}]}
      industry_b = %Industry{id: 7, name: "Tech", tags: [%Tag{id: 200, name: "b"}]}
      author = %User{id: 1, company: %Company{id: 9, industry: industry_a}}
      other_user = %User{id: 2, company: %Company{id: 10, industry: industry_b}}
      post = %Post{id: 1, text: "Hello", author: author, other_user: other_user}

      document = JSONAPIPlug.render(conn, post)

      assert [%ResourceObject{relationships: %{"tags" => tags}}] =
               included_with_id(document, "industry", "7")

      assert tags.data |> Enum.map(& &1.id) |> Enum.sort() == ["100", "200"]
    end
  end
end
