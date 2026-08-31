defmodule JSONAPIPlug.APITest do
  use ExUnit.Case, async: false

  alias JSONAPIPlug.API

  defmodule VersionOneZeroAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule VersionOneOneAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule ExtensionsAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  defmodule ProfilesAPI do
    @moduledoc false
    use JSONAPIPlug.API, otp_app: :jsonapi_plug
  end

  setup do
    :persistent_term.erase(VersionOneZeroAPI)
    :persistent_term.erase(VersionOneOneAPI)
    :persistent_term.erase(ExtensionsAPI)
    :persistent_term.erase(ProfilesAPI)

    Application.put_env(:jsonapi_plug, VersionOneZeroAPI, version: :"1.0")
    Application.put_env(:jsonapi_plug, VersionOneOneAPI, version: :"1.1")

    Application.put_env(:jsonapi_plug, ExtensionsAPI, extensions: ["https://example.com/ext"])

    Application.put_env(:jsonapi_plug, ProfilesAPI, profiles: ["https://example.com/profile"])

    on_exit(fn ->
      :persistent_term.erase(VersionOneZeroAPI)
      :persistent_term.erase(VersionOneOneAPI)
      :persistent_term.erase(ExtensionsAPI)
      :persistent_term.erase(ProfilesAPI)
    end)

    :ok
  end

  test "version 1.0 is valid" do
    config = API.get_config(VersionOneZeroAPI)
    assert config[:version] == :"1.0"
  end

  test "version 1.1 is valid" do
    config = API.get_config(VersionOneOneAPI)
    assert config[:version] == :"1.1"
  end

  test "invalid version raises error" do
    Application.put_env(:jsonapi_plug, VersionOneZeroAPI, version: :"1.2")
    :persistent_term.erase(VersionOneZeroAPI)

    assert_raise NimbleOptions.ValidationError, fn ->
      API.get_config(VersionOneZeroAPI)
    end
  end

  test "extensions list is stored and retrievable" do
    config = API.get_config(ExtensionsAPI)
    assert config[:extensions] == ["https://example.com/ext"]
  end

  test "extensions defaults to empty list" do
    config = API.get_config(VersionOneZeroAPI)
    assert config[:extensions] == []
  end

  test "profiles list is stored and retrievable" do
    config = API.get_config(ProfilesAPI)
    assert config[:profiles] == ["https://example.com/profile"]
  end

  test "profiles defaults to empty list" do
    config = API.get_config(VersionOneZeroAPI)
    assert config[:profiles] == []
  end

  test "invalid extensions type raises error" do
    Application.put_env(:jsonapi_plug, ExtensionsAPI, extensions: "not-a-list")
    :persistent_term.erase(ExtensionsAPI)

    assert_raise NimbleOptions.ValidationError, fn ->
      API.get_config(ExtensionsAPI)
    end
  end

  describe "JSONAPIObject encoding" do
    test "encodes version 1.0" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{version: :"1.0"}
      encoded = Jason.decode!(Jason.encode!(jsonapi))
      assert encoded["version"] == "1.0"
      refute Map.has_key?(encoded, "ext")
      refute Map.has_key?(encoded, "profile")
    end

    test "encodes version 1.1" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{version: :"1.1"}
      encoded = Jason.decode!(Jason.encode!(jsonapi))
      assert encoded["version"] == "1.1"
    end

    test "encodes ext array when present" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{
        version: :"1.1",
        ext: ["https://example.com/ext"]
      }

      encoded = Jason.decode!(Jason.encode!(jsonapi))
      assert encoded["ext"] == ["https://example.com/ext"]
    end

    test "omits ext key when nil" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{version: :"1.0", ext: nil}
      encoded = Jason.decode!(Jason.encode!(jsonapi))
      refute Map.has_key?(encoded, "ext")
    end

    test "encodes profile array when present" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{
        version: :"1.1",
        profile: ["https://example.com/profile"]
      }

      encoded = Jason.decode!(Jason.encode!(jsonapi))
      assert encoded["profile"] == ["https://example.com/profile"]
    end

    test "omits profile key when nil" do
      jsonapi = %JSONAPIPlug.Document.JSONAPIObject{version: :"1.0", profile: nil}
      encoded = Jason.decode!(Jason.encode!(jsonapi))
      refute Map.has_key?(encoded, "profile")
    end
  end
end
