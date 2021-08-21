defmodule JSONAPI.TestSupport.Paginators do
  @moduledoc false

  defmodule PageBasedPaginator do
    @moduledoc """
    Page based pagination strategy
    """

    alias JSONAPI.Paginator

    @behaviour Paginator

    @impl Paginator
    def paginate(view, resources, conn, page, options) do
      number =
        page
        |> Map.get("page", "0")
        |> String.to_integer()

      size =
        page
        |> Map.get("size", "0")
        |> String.to_integer()

      total_pages =
        options
        |> Keyword.get(:total_pages, 0)

      %{
        first: Paginator.url_for(view, resources, conn, %{page | "page" => "1"}),
        last: Paginator.url_for(view, resources, conn, %{page | "page" => total_pages}),
        next: next_link(resources, view, conn, number, size, total_pages),
        prev: previous_link(resources, view, conn, number, size),
        self: Paginator.url_for(view, resources, conn, %{size: size, page: number})
      }
    end

    defp next_link(resources, view, conn, page, size, total_pages)
         when page < total_pages,
         do: Paginator.url_for(view, resources, conn, %{size: size, page: page + 1})

    defp next_link(_resources, _view, _conn, _page, _size, _total_pages),
      do: nil

    defp previous_link(resources, view, conn, page, size)
         when page > 1,
         do: Paginator.url_for(view, resources, conn, %{size: size, page: page - 1})

    defp previous_link(_resources, _view, _conn, _page, _size),
      do: nil
  end
end
