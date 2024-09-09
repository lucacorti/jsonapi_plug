defmodule JSONAPIPlug.TestSupport.Resources do
  @moduledoc false

  defmodule Tag do
    @moduledoc false

    @derive {JSONAPIPlug.Resource, type: "tag", attributes: [name: []]}
    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.Tag

    @derive {
      JSONAPIPlug.Resource,
      type: "industry", attributes: [:name], relationships: [tags: [many: true, resource: Tag]]
    }

    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    alias JSONAPIPlug.TestSupport.Resources.Industry

    @derive {
      JSONAPIPlug.Resource,
      type: "company", attributes: [:name], relationships: [industry: [resource: Industry]]
    }
    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
    alias JSONAPIPlug.TestSupport.Resources.{Company, Post}

    @derive {
      JSONAPIPlug.Resource,
      type: "user",
      attributes: [
        age: nil,
        first_name: nil,
        last_name: nil,
        full_name: [deserialize: false],
        username: nil,
        password: nil
      ],
      relationships: [
        company: [resource: Company],
        top_posts: [resource: Post, many: true]
      ]
    }

    defstruct id: nil,
              age: nil,
              username: nil,
              password: nil,
              first_name: nil,
              last_name: nil,
              company: nil
  end

  defmodule Car do
    @moduledoc false
    @derive {JSONAPIPlug.Resource, type: "car", attributes: [:model]}
    defstruct id: nil, model: nil
  end

  defmodule Comment do
    @moduledoc false
    alias JSONAPIPlug.TestSupport.Resources.User

    @derive {
      JSONAPIPlug.Resource,
      type: "comment", attributes: [:body, :text], relationships: [user: [resource: User]]
    }
    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.{Comment, User}

    @derive {
      JSONAPIPlug.Resource,
      type: "post",
      attributes: [
        text: nil,
        body: nil,
        title: nil,
        excerpt: [deserialize: false],
        first_character: [deserialize: false],
        second_character: [deserialize: false],
        full_description: nil,
        inserted_at: nil
      ],
      relationships: [
        author: [resource: User],
        best_comments: [resource: Comment, many: true],
        other_user: [resource: User]
      ]
    }

    defstruct id: nil,
              title: nil,
              text: nil,
              body: nil,
              full_description: nil,
              inserted_at: nil,
              author: nil,
              other_user: nil,
              best_comments: []
  end
end

defimpl JSONAPIPlug.Resource.Attribute, for: JSONAPIPlug.TestSupport.Resources.Post do
  def render(%@for{} = post, :excerpt, _conn), do: String.slice(post.text, 0..4)
  def render(%@for{} = post, :first_character, _conn), do: String.slice(post.text, 0..0)
  def render(%@for{} = post, :second_character, _conn), do: String.slice(post.text, 1..1)
  def render(resource, field_name, _conn), do: Map.get(resource, field_name)
  def parse(_resource, _field_name, value, _conn), do: value
end

defimpl JSONAPIPlug.Resource.Meta, for: JSONAPIPlug.TestSupport.Resources.Post do
  def meta(%@for{} = post, _conn),
    do: %{"meta_text" => "meta_#{String.slice(post.text, 0..4) |> String.downcase()}"}
end

defimpl JSONAPIPlug.Resource.Attribute, for: JSONAPIPlug.TestSupport.Resources.User do
  def render(%@for{} = user, :full_name, _conn),
    do: Enum.join([user.first_name, user.last_name], " ")

  def render(resource, field_name, _conn), do: Map.get(resource, field_name)
  def parse(_resource, _field_name, value, _conn), do: value
end
