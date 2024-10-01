defmodule JSONAPIPlug.TestSupport.Pagination do
  @moduledoc false

  defmodule PageBasedPagination do
    @moduledoc """
    Page based pagination strategy
    """

    @behaviour JSONAPIPlug.Pagination

    @impl JSONAPIPlug.Pagination
    def paginate(resources, conn, page, options) when not is_nil(page) and is_list(resources) do
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
        first: JSONAPIPlug.Pagination.url_for(resources, conn, Map.put(page, "page", 1)),
        last: JSONAPIPlug.Pagination.url_for(resources, conn, Map.put(page, "page", total_pages)),
        next: next_link(resources, conn, number, size, total_pages),
        prev: previous_link(resources, conn, number, size),
        self: JSONAPIPlug.Pagination.url_for(resources, conn, %{"size" => size, "page" => number})
      }
    end

    def paginate(_resources, _conn, _page, _options), do: %{}

    defp next_link(resources, conn, page, size, total_pages)
         when page < total_pages,
         do:
           JSONAPIPlug.Pagination.url_for(resources, conn, %{"size" => size, "page" => page + 1})

    defp next_link(_resources, _conn, _page, _size, _total_pages),
      do: nil

    defp previous_link(resources, conn, page, size)
         when page > 1,
         do:
           JSONAPIPlug.Pagination.url_for(resources, conn, %{"size" => size, "page" => page - 1})

    defp previous_link(_resources, _conn, _page, _size),
      do: nil
  end
end
