defmodule JSONAPI.TestSupport.Resources do
  @moduledoc false

  alias JSONAPI.Resource.Serializable

  defmodule Tag do
    @moduledoc false
    @derive {Serializable, id: :id, type: "tag", attributes: [:name]}
    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false
    @derive {Serializable,
             id: :id,
             type: "industry",
             attributes: [:name],
             relationships: [tags: [many: true, type: Tag]]}
    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    @derive {Serializable,
             id: :id,
             type: "company",
             attributes: [:name],
             relationships: [industry: [type: Industry]]}
    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
    @derive {
      Serializable,
      id: :id,
      type: "user",
      attributes: [:age, :username, :password, :first_name, :last_name],
      relationships: [company: [type: Company]]
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
    @derive {Serializable, id: :id, type: "car"}
    defstruct id: nil
  end

  defmodule Comment do
    @moduledoc false
    @derive {
      Serializable,
      id: :id,
      type: "comment",
      attributes: [:text, :body],
      relationships: [user: [type: User], post: [type: Post]]
    }
    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false
    @derive {
      Serializable,
      id: :id,
      type: "post",
      attributes: [:text, :title, :body],
      relationships: [
        author: [type: User],
        other_user: [type: User],
        best_comments: [many: true, type: Comment]
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
