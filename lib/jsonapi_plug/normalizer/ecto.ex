defmodule JSONAPIPlug.Normalizer.Ecto do
  @moduledoc """
  JSON:API Document normalizer implementation for Ecto

  Translating `JSON:API` resources to and from an Ecto friendly format in conn params.
  Deserialization produces attributes and relationships in a way that directly translates
  to attributes that can be passed to an `Ecto.Changeset` for validation and later to
  `Ecto.Repo` for database operations.
  """

  alias JSONAPIPlug.Document.{RelationshipObject, ResourceIdentifierObject}
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
    params
    |> Map.put(to_string(relationship), value)
    |> Map.put("#{relationship}_id", Enum.map(data, &Map.get(&1, :id)))
  end

  def denormalize_relationship(
        params,
        %RelationshipObject{data: %ResourceIdentifierObject{} = data},
        relationship,
        value
      ) do
    params
    |> Map.put(to_string(relationship), value)
    |> Map.put("#{relationship}_id", data.id)
  end

  def denormalize_relationship(params, _relationship_objects, relationship, value),
    do: Map.put(params, to_string(relationship), value)

  @impl Normalizer
  def normalize_attribute(params, attribute), do: Map.get(params, attribute)
end
