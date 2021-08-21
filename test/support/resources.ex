defmodule JSONAPI.TestSupport.Resources do
  @moduledoc false

  alias JSONAPI.Resource.{Identifiable, Serializable}
  alias JSONAPI.TestSupport.Views.{CommentView, CompanyView, UserView}

  defmodule Tag do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "tag"}
    @derive {Serializable, attributes: [:name]}
    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "industry"}
    @derive {Serializable, attributes: [:name], has_many: [tags: Tag]}
    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "company"}
    @derive {Serializable, attributes: [:name], has_one: [industry: Company]}
    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "user"}
    @derive {
      Serializable,
      attributes: [:age, :username, :password, :first_name, :last_name],
      has_one: [company: CompanyView]
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
    @derive {Identifiable, id_attribute: :id, type: "car"}
    @derive Serializable
    defstruct id: nil
  end

  defmodule Comment do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "comment"}
    @derive {
      Serializable,
      attributes: [:text, :body], has_one: [user: UserView, post: PostView]
    }
    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false
    @derive {Identifiable, id_attribute: :id, type: "post"}
    @derive {
      Serializable,
      attributes: [:text, :title, :body],
      has_one: [author: UserView, other_user: UserView],
      has_many: [best_comments: CommentView]
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
