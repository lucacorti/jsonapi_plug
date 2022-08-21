defmodule JSONAPIPlug.TestSupport.Resources do
  @moduledoc false

  defmodule Tag do
    @moduledoc false
    defstruct id: nil, name: nil
  end

  defmodule Industry do
    @moduledoc false
    defstruct id: nil, name: nil, tags: []
  end

  defmodule Company do
    @moduledoc false
    defstruct id: nil, name: nil, industry: nil
  end

  defmodule User do
    @moduledoc false
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
    defstruct id: nil
  end

  defmodule Comment do
    @moduledoc false
    defstruct id: nil, text: nil, body: nil, user: nil, post: []
  end

  defmodule Post do
    @moduledoc false
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
