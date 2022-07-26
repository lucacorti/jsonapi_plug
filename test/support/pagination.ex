defmodule JSONAPI.TestSupport.Pagination do
  @moduledoc false

  defmodule PageBasedPagination do
    @moduledoc """
    Page based pagination strategy
    """

    alias JSONAPI.Pagination

    @behaviour Pagination

    @impl Pagination
    def paginate(view, resources, conn, page, options) do
      number =
        page
        |> Map.get("page", "0")
        |> String.to_integer()

      size =
        page
        |> Map.get("size", "0")
        |> String.to_integer()

      total_pages = Keyword.get(options, :total_pages, 0)

      %{
        first: Pagination.url_for(view, resources, conn, Map.put(page, "page", 1)),
        last: Pagination.url_for(view, resources, conn, Map.put(page, "page", total_pages)),
        next: next_link(resources, view, conn, number, size, total_pages),
        prev: previous_link(resources, view, conn, number, size),
        self: Pagination.url_for(view, resources, conn, %{"size" => size, "page" => number})
      }
    end

    defp next_link(resources, view, conn, page, size, total_pages)
         when page < total_pages,
         do: Pagination.url_for(view, resources, conn, %{"size" => size, "page" => page + 1})

    defp next_link(_resources, _view, _conn, _page, _size, _total_pages),
      do: nil

    defp previous_link(resources, view, conn, page, size)
         when page > 1,
         do: Pagination.url_for(view, resources, conn, %{"size" => size, "page" => page - 1})

    defp previous_link(_resources, _view, _conn, _page, _size),
      do: nil
  end
end
