defmodule JSONAPIPlug.Normalizer.Ecto do
  @moduledoc """
  JSON:API Document normalizer implementation for Ecto

  Translates `JSON:API` resources to an Ecto friendly format in conn params.
  Deserialization produces attributes and relationships in a way that directly translates
  to attributes that can be passed to an `Ecto.Changeset` for validation and later to
  `Ecto.Repo` for database operations.
  """

  alias JSONAPIPlug.Document.RelationshipObject
  alias JSONAPIPlug.Normalizer

  @behaviour Normalizer

  @impl Normalizer
  def resource_params, do: %{}

  @impl Normalizer
  def denormalize_attribute(params, attribute, value),
    do: Map.put(params, to_string(attribute), value)

  @impl Normalizer
  def denormalize_relationship(
        params,
        %RelationshipObject{data: data},
        relationship,
        value
      )
      when is_list(data) do
    Map.put(params, to_string(relationship), value)
  end

  def denormalize_relationship(
        params,
        %RelationshipObject{data: data},
        relationship,
        value
      ) do
    params = Map.put(params, to_string(relationship), value)

    if data.id do
      Map.put(params, "#{relationship}_id", data.id)
    else
      params
    end
  end
end
