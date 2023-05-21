defprotocol JSONAPIPlug.Resource.Case do
  alias JSONAPIPlug.Resource
  alias Plug.Conn

  @type params :: Conn.params()
  @type value :: term()

  @spec fields_case(t()) :: Resource.field_case()
  def fields_case(t)
end
