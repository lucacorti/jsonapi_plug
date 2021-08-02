defmodule JSONAPI.SupportTest do
  @moduledoc false

  defmodule Tag do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "industry"}
    @derive {JSONAPI.Resource.Serializable, attributes: [:name]}
    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "industry"}
    @derive {JSONAPI.Resource.Serializable, attributes: [:name], has_many: [tags: Tag]}
    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "company"}
    @derive {JSONAPI.Resource.Serializable, attributes: [:name], has_one: [industry: Company]}
    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "user"}
    @derive {
      JSONAPI.Resource.Serializable,
      attributes: [:age, :username, :password, :first_name, :last_name],
      has_one: [company: Company]
    }
    defstruct id: nil,
              age: nil,
              username: nil,
              password: nil,
              first_name: nil,
              last_name: nil,
              company: nil
  end

  defmodule Comment do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "comment"}
    @derive {
      JSONAPI.Resource.Serializable,
      attributes: [:text, :body], has_one: [user: User], has_one: [post: Post]
    }
    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false
    @derive {JSONAPI.Resource.Identifiable, id_attribute: :id, type: "post"}
    @derive {
      JSONAPI.Resource.Serializable,
      attributes: [:text, :title, :body],
      has_one: [author: User, other_user: User],
      has_many: [best_comments: Comment]
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
