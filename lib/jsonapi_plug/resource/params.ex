defprotocol JSONAPIPlug.Resource.Params do
  alias JSONAPIPlug.{Document.RelationshipObject, Document.ResourceIdentifierObject, Resource}
  alias Plug.Conn

  @type params :: Conn.params()
  @type value :: term()

  @fallback_to_any true

  @spec init(t()) :: params() | no_return()
  def init(t)

  @spec attribute_to_params(t(), params(), String.t(), term()) ::
          params() | no_return()
  def attribute_to_params(t, params, field_name, value)

  @spec relationship_to_params(
          t(),
          params(),
          RelationshipObject.t() | [RelationshipObject.t()],
          String.t(),
          term()
        ) :: params() | no_return()
  def relationship_to_params(t, params, relationships, field_name, value)

  @spec render_attribute(t(), Resource.field_name()) :: value() | no_return()
  def render_attribute(t, field_name)
end

defimpl JSONAPIPlug.Resource.Params, for: Any do
  alias JSONAPIPlug.{Document.RelationshipObject, Document.ResourceIdentifierObject}

  def init(_t), do: %{}

  def attribute_to_params(_t, params, attribute, value),
    do: Map.put(params, to_string(attribute), value)

  def relationship_to_params(
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

  def relationship_to_params(_t, params, _relationship_objects, relationship, value),
    do: Map.put(params, to_string(relationship), value)

  def render_attribute(t, attribute), do: Map.get(t, attribute)
end
