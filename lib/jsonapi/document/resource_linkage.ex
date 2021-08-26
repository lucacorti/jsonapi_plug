defmodule JSONAPI.Document.ResourceLinkage do
  @moduledoc """
  JSON:API Resource Identifier object

  https://jsonapi.org/format/#document-resource-object-linkage
  """

  alias JSONAPI.{Document, Resource}

  @type t :: %__MODULE__{id: Resource.id(), type: Resource.type(), meta: Document.meta()}
  @enforce_keys [:id, :type]
  defstruct [:id, :type, :meta]
end
