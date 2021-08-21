defmodule JSONAPI.TestSupport.Views do
  @moduledoc false

  alias JSONAPI.TestSupport.Paginators.PageBasedPaginator
  alias JSONAPI.TestSupport.Resources.{Car, Comment, Company, Industry, Post, Tag, User}

  defmodule CarView do
    @moduledoc false

    use JSONAPI.View, resource: Car
  end

  defmodule CommentView do
    @moduledoc false

    use JSONAPI.View, resource: Comment

    alias JSONAPI.TestSupport.Views.UserView

    @impl JSONAPI.View
    def attributes(_resource), do: [:body, :text]

    @impl JSONAPI.View
    def relationships(_resource), do: [user: UserView]
  end

  defmodule CompanyView do
    @moduledoc false

    use JSONAPI.View, resource: Company

    alias JSONAPI.TestSupport.Views.IndustryView

    @impl JSONAPI.View
    def attributes(_resource), do: [:name]

    @impl JSONAPI.View
    def relationships(_resource), do: [industry: IndustryView]
  end

  defmodule ExpensiveResourceView do
    @moduledoc false

    use JSONAPI.View, resource: Post

    @impl JSONAPI.View
    def attributes(_resource), do: [:name]

    @impl JSONAPI.View
    def type, do: "expensive-post"

    @impl JSONAPI.View
    def links(nil, _conn), do: %{}

    @impl JSONAPI.View
    def links(data, _conn) do
      %{
        queue: "/expensive-post/queue/#{data.id}",
        promotions: %{
          href: "/promotions?rel=#{data.id}",
          meta: %{
            title: "Stuff you might be interested in"
          }
        }
      }
    end
  end

  defmodule IndustryView do
    @moduledoc false

    use JSONAPI.View, resource: Industry

    alias JSONAPI.TestSupport.Views.TagView

    @impl JSONAPI.View
    def attributes(_resource), do: [:name]

    @impl JSONAPI.View
    def relationships(_resource), do: [tags: TagView]
  end

  defmodule MyPostView do
    @moduledoc false

    use JSONAPI.View, resource: Post

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def attributes(_resource), do: [:text, :body]

    @impl JSONAPI.View
    def type, do: "my-type"

    @impl JSONAPI.View
    def relationships(_resource) do
      [
        author: UserView,
        comments: CommentView,
        best_friends: UserView
      ]
    end
  end

  defmodule NotIncludedView do
    @moduledoc false

    use JSONAPI.View, resource: Post, type: "not-included"

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def attributes(_resource), do: [:foo]

    @impl JSONAPI.View
    def relationships(_resource) do
      [author: UserView, best_comments: CommentView]
    end
  end

  defmodule PaginatedPostView do
    @moduledoc false

    use JSONAPI.View, resource: Post, paginator: PageBasedPaginator

    @impl JSONAPI.View
    def attributes(_resource), do: [:text, :body, :full_description, :inserted_at]

    @impl JSONAPI.View
    def type, do: "post"
  end

  defmodule PostView do
    @moduledoc false

    use JSONAPI.View, resource: Post, path: "posts"

    alias JSONAPI.TestSupport.Views.{CommentView, UserView}

    @impl JSONAPI.View
    def attributes(_resource),
      do: [:text, :body, :excerpt, :first_character, :full_description, :inserted_at]

    @impl JSONAPI.View
    def meta(%Post{} = post, _conn), do: %{meta_text: "meta_#{post.text}"}

    @impl JSONAPI.View
    def relationships(_resource) do
      [
        author: UserView,
        best_comments: CommentView,
        other_user: UserView
      ]
    end

    def excerpt(post, _conn), do: String.slice(post.text, 0..1)

    def first_character(post, _conn), do: String.first(post.text)
  end

  defmodule TagView do
    @moduledoc false

    use JSONAPI.View, resource: Tag
  end

  defmodule UserView do
    @moduledoc false

    use JSONAPI.View, resource: User, namespace: "cake", path: "users"

    alias JSONAPI.TestSupport.Views.{CompanyView, MyPostView}

    @impl JSONAPI.View
    def attributes(_resource),
      do: [:age, :first_name, :last_name, :full_name, :username, :password]

    @impl JSONAPI.View
    def relationships(_resource),
      do: [
        company: CompanyView,
        top_posts: MyPostView
      ]

    def full_name(user, _conn), do: Enum.join([user.first_name, user.last_name], " ")
  end
end
