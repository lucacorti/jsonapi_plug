defmodule JSONAPIPlug.TestSupport.Resources do
  @moduledoc false

  defmodule Tag do
    @moduledoc false
    use JSONAPIPlug.Resource, resource: __MODULE__, type: "tag", attributes: [name: nil]

    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false

    use JSONAPIPlug.Resource,
      resource: __MODULE__,
      type: "industry",
      attributes: [name: nil],
      relationships: [tags: [many: true, resource: Tag]]

    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    use JSONAPIPlug.Resource,
      resource: __MODULE__,
      type: "company",
      relationships: [industry: [resource: Industry]]

    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
    use JSONAPIPlug.Resource,
      resource: __MODULE__,
      type: "user",
      attributes: [
        age: nil,
        first_name: nil,
        last_name: nil,
        full_name: [
          serialize: fn user, _conn -> Enum.join([user.first_name, user.last_name], " ") end
        ],
        username: nil,
        password: nil
      ],
      relationships: [
        company: [resource: Company],
        top_posts: [resource: Post, many: true]
      ]

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
    use JSONAPIPlug.Resource, resource: __MODULE__, type: "car"
    defstruct id: nil
  end

  defmodule Comment do
    @moduledoc false
    use JSONAPIPlug.Resource,
      resource: __MODULE__,
      type: "comment",
      attributes: [body: nil, text: nil],
      relationships: [user: [resource: User]]

    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false
    use JSONAPIPlug.Resource,
      resource: __MODULE__,
      type: "post",
      attributes: [
        text: nil,
        body: nil,
        excerpt: [
          serialize: fn post, _conn -> String.slice(post.text, 0..1) end
        ],
        first_character: [
          serialize: fn post, _conn -> String.first(post.text) end
        ],
        full_description: nil,
        inserted_at: nil
      ],
      relationships: [
        author: [resource: User],
        best_comments: [resource: Comment, many: true],
        other_user: [resource: User]
      ]

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
