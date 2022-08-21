defmodule JSONAPI.TestSupport.Views do
  @moduledoc false

  alias JSONAPI.TestSupport.Resources.{Post, User}

  defmodule CarView do
    @moduledoc false

    use JSONAPI.View, type: "car"
  end

  defmodule CommentView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.UserView

    use JSONAPI.View,
      type: "comment",
      attributes: [:body, :text],
      relationships: [user: [view: UserView]]
  end

  defmodule CompanyView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.IndustryView

    use JSONAPI.View,
      type: "company",
      attributes: [:name],
      relationships: [industry: [view: IndustryView]]
  end

  defmodule ExpensiveResourceView do
    @moduledoc false

    use JSONAPI.View,
      type: "expensive-post",
      attributes: [:name]

    @impl JSONAPI.View
    def links(nil, _conn), do: %{}

    @impl JSONAPI.View
    def links(resource, _conn) do
      %{
        queue: "/expensive-post/queue/#{resource.id}",
        promotions: %{
          href: "/promotions?rel=#{resource.id}",
          meta: %{
            title: "Stuff you might be interested in"
          }
        }
      }
    end
  end

  defmodule IndustryView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.TagView

    use JSONAPI.View,
      type: "industry",
      attributes: [:name],
      relationships: [tags: [many: true, view: TagView]]
  end

  defmodule MyPostView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    use JSONAPI.View,
      type: "my-type",
      attributes: [:body, :text, :title],
      relationships: [
        author: [view: UserView],
        comments: [view: CommentView, many: true],
        best_friends: [view: UserView, many: true]
      ]
  end

  defmodule NotIncludedView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    use JSONAPI.View,
      type: "not-included",
      attributes: [:foo],
      relationships: [
        author: [view: UserView],
        best_comments: [view: CommentView, many: true]
      ]
  end

  defmodule PostView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    use JSONAPI.View,
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
        author: [view: UserView],
        best_comments: [view: CommentView, many: true],
        other_user: [view: UserView]
      ]

    @impl JSONAPI.View
    def meta(%Post{} = post, _conn), do: %{meta_text: "meta_#{post.text}"}
  end

  defmodule TagView do
    @moduledoc false

    use JSONAPI.View, type: "tag"
  end

  defmodule UserView do
    @moduledoc false

    alias JSONAPI.TestSupport.Views.{CompanyView, MyPostView}

    use JSONAPI.View,
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
        company: [view: CompanyView],
        top_posts: [view: MyPostView, many: true]
      ]

    defp full_name(%User{} = user, _conn),
      do: Enum.join([user.first_name, user.last_name], " ")
  end
end
