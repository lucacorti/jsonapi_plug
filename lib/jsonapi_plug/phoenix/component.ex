defmodule JSONAPIPlug.Phoenix.Component do
  @moduledoc "JSONAPIPlug Phoenix Component helper"

  defmacro __using__(_options \\ []) do
    quote do
      @doc """
      JSONAPIPlug generated resource render function

      It takes the action (one of "create.json", "index.json", "show.json", "update.json") and
      the assings as a keyword list or map with atom keys.
      """
      @spec render(action :: String.t(), assigns :: keyword() | %{atom() => term()}) ::
              JSONAPIPlug.Document.t() | no_return()
      def render(action, assigns)
          when action in ["create.json", "index.json", "show.json", "update.json"] do
        JSONAPIPlug.render(
          assigns[:conn],
          assigns[:data],
          assigns[:meta],
          assigns[:options]
        )
      end

      def render(action, _assigns) do
        raise "invalid action #{action}, use one of create.json, index.json, show.json, update.json"
      end
    end
  end
end
