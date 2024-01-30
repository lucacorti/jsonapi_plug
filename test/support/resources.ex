defmodule JSONAPIPlug.TestSupport.Resources do
  @moduledoc false

  alias JSONAPIPlug.TestSupport.Schemas.{Post, User}

  defmodule CarResource do
    @moduledoc false

    use JSONAPIPlug.Resource, type: "car", attributes: [:model]
  end

  defmodule CommentResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.UserResource

    use JSONAPIPlug.Resource,
      type: "comment",
      attributes: [:body, :text],
      relationships: [user: [resource: UserResource]]
  end

  defmodule CompanyResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.IndustryResource

    use JSONAPIPlug.Resource,
      type: "company",
      attributes: [:name],
      relationships: [industry: [resource: IndustryResource]]
  end

  defmodule ExpensiveResourceResource do
    @moduledoc false

    use JSONAPIPlug.Resource,
      type: "expensive-post",
      attributes: [:name]

    @impl JSONAPIPlug.Resource
    def links(nil, _conn), do: %{}

    @impl JSONAPIPlug.Resource
    def links(resource, _conn) do
      %{
        queue: "/expensive-post/queue/#{resource.id}",
        promotions: %{
          href: "/promotions?rel=#{resource.id}",
          meta: %{"title" => "Stuff you might be interested in"}
        }
      }
    end
  end

  defmodule IndustryResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.TagResource

    use JSONAPIPlug.Resource,
      type: "industry",
      attributes: [:name],
      relationships: [tags: [many: true, resource: TagResource]]
  end

  defmodule MyPostResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.{CommentResource, UserResource}

    use JSONAPIPlug.Resource,
      type: "my-type",
      attributes: [:body, :text, :title],
      relationships: [
        author: [resource: UserResource],
        comments: [resource: CommentResource, many: true],
        best_friends: [resource: UserResource, many: true]
      ]
  end

  defmodule NotIncludedResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.{CommentResource, UserResource}

    use JSONAPIPlug.Resource,
      type: "not-included",
      attributes: [:foo],
      relationships: [
        author: [resource: UserResource],
        best_comments: [resource: CommentResource, many: true]
      ]
  end

  defmodule PostResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.{CommentResource, UserResource}

    use JSONAPIPlug.Resource,
      type: "post",
      path: "posts",
      attributes: [
        text: nil,
        body: nil,
        excerpt: [serialize: fn %Post{} = post, _conn -> String.slice(post.text, 0..1) end],
        first_character: [serialize: fn %Post{} = post, _conn -> String.first(post.text) end],
        full_description: nil,
        inserted_at: nil
      ],
      relationships: [
        author: [resource: UserResource],
        best_comments: [resource: CommentResource, many: true],
        other_user: [resource: UserResource]
      ]

    @impl JSONAPIPlug.Resource
    def meta(%Post{} = post, _conn), do: %{"meta_text" => "meta_#{post.text}"}
  end

  defmodule TagResource do
    @moduledoc false

    use JSONAPIPlug.Resource, type: "tag", attributes: [:name]
  end

  defmodule UserResource do
    @moduledoc false

    alias JSONAPIPlug.TestSupport.Resources.{CompanyResource, MyPostResource}

    use JSONAPIPlug.Resource,
      type: "user",
      path: "users",
      attributes: [
        age: nil,
        first_name: nil,
        last_name: nil,
        full_name: [serialize: &full_name/2],
        username: nil,
        password: nil
      ],
      relationships: [
        company: [resource: CompanyResource],
        top_posts: [resource: MyPostResource, many: true]
      ]

    defp full_name(%User{} = user, _conn),
      do: Enum.join([user.first_name, user.last_name], " ")
  end
end
