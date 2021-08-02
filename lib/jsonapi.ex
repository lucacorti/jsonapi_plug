defmodule JSONAPI do
  @moduledoc """
  A module for working with the JSON API specification in Elixir
  """

  @mime_type "application/vnd.api+json"

  @doc """
  This returns the MIME type for JSONAPIs
  """
  @spec mime_type :: String.t()
  def mime_type, do: @mime_type
end
