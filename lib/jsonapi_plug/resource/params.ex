defprotocol JSONAPIPlug.Resource.Params do
  alias JSONAPIPlug.{Document.RelationshipObject, Document.ResourceIdentifierObject, Resource}
  alias Plug.Conn

  @type params :: Conn.params()
  @type value :: term()

  @fallback_to_any true

  @spec resource_params(t()) :: params() | no_return()
  def resource_params(t)

  @spec denormalize_attribute(t(), params(), String.t(), term()) ::
          params() | no_return()
  def denormalize_attribute(t, params, field_name, value)

  @spec denormalize_relationship(
          t(),
          params(),
          RelationshipObject.t() | [RelationshipObject.t()],
          String.t(),
          term()
        ) :: params() | no_return()
  def denormalize_relationship(t, params, relationships, field_name, value)

  @spec normalize_attribute(t(), Resource.field_name()) :: value() | no_return()
  def normalize_attribute(t, field_name)
end

defimpl JSONAPIPlug.Resource.Params, for: Any do
  alias JSONAPIPlug.{Document.RelationshipObject, Document.ResourceIdentifierObject}

  def resource_params(_t), do: %{}

  def denormalize_attribute(_t, params, attribute, value),
    do: Map.put(params, to_string(attribute), value)

  def denormalize_relationship(
        _t,
        params,
        %RelationshipObject{data: %ResourceIdentifierObject{} = data},
        relationship,
        value
      ) do
    params
    |> Map.put(to_string(relationship), value)
    |> Map.put("#{relationship}_id", data.id)
  end

  def denormalize_relationship(_t, params, _relationship_objects, relationship, value),
    do: Map.put(params, to_string(relationship), value)

  def normalize_attribute(t, attribute), do: Map.get(t, attribute)
end
