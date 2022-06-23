defmodule JSONAPI.TestSupport.Views do
  @moduledoc false

  alias JSONAPI.TestSupport.Resources.{Post, User}

  defmodule CarView do
    @moduledoc false

    use JSONAPI.View, type: "car"
  end

  defmodule CommentView do
    @moduledoc false

    use JSONAPI.View, type: "comment"

    alias JSONAPI.TestSupport.Views.UserView

    @impl JSONAPI.View
    def attributes, do: [:body, :text]

    @impl JSONAPI.View
    def relationships, do: [user: [view: UserView]]
  end

  defmodule CompanyView do
    @moduledoc false

    use JSONAPI.View, type: "company"

    alias JSONAPI.TestSupport.Views.IndustryView

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def relationships, do: [industry: [view: IndustryView]]
  end

  defmodule ExpensiveResourceView do
    @moduledoc false

    use JSONAPI.View, type: "post"

    @impl JSONAPI.View
    def type, do: "expensive-post"

    @impl JSONAPI.View
    def attributes, do: [:name]

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

    use JSONAPI.View, type: "industry"

    alias JSONAPI.TestSupport.Views.TagView

    @impl JSONAPI.View
    def attributes, do: [:name]

    @impl JSONAPI.View
    def relationships, do: [tags: [view: TagView]]
  end

  defmodule MyPostView do
    @moduledoc false

    use JSONAPI.View, type: "post"

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def type, do: "my-type"

    @impl JSONAPI.View
    def attributes, do: [:text, :body]

    @impl JSONAPI.View
    def relationships,
      do: [
        author: [view: UserView],
        comments: [view: CommentView, many: true],
        best_friends: [view: UserView, many: true]
      ]
  end

  defmodule NotIncludedView do
    @moduledoc false

    use JSONAPI.View, type: "post"

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def type, do: "not-included"

    @impl JSONAPI.View
    def attributes, do: [:foo]

    @impl JSONAPI.View
    def relationships,
      do: [
        author: [view: UserView],
        best_comments: [view: CommentView, many: true]
      ]
  end

  defmodule PostView do
    @moduledoc false

    use JSONAPI.View, type: "post", path: "posts"

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def attributes,
      do: [:text, :body, :excerpt, :first_character, :full_description, :inserted_at]

    @impl JSONAPI.View
    def meta(%Post{} = post, _conn), do: %{meta_text: "meta_#{post.text}"}

    @impl JSONAPI.View
    def relationships,
      do: [
        author: [view: UserView],
        best_comments: [view: CommentView, many: true],
        other_user: [view: UserView]
      ]

    def excerpt(%Post{} = post, _conn), do: String.slice(post.text, 0..1)
    def first_character(%Post{} = post, _conn), do: String.first(post.text)
  end

  defmodule TagView do
    @moduledoc false

    use JSONAPI.View, type: "tag"
  end

  defmodule UserView do
    @moduledoc false

    use JSONAPI.View, type: "user", path: "users"

    alias JSONAPI.TestSupport.Views.{CompanyView, MyPostView}

    @impl JSONAPI.View
    def attributes,
      do: [:age, :first_name, :last_name, :full_name, :username, :password]

    @impl JSONAPI.View
    def relationships,
      do: [
        company: [view: CompanyView],
        top_posts: [view: MyPostView, many: true]
      ]

    def full_name(%User{} = user, _conn), do: Enum.join([user.first_name, user.last_name], " ")
  end
end
