defmodule PowAssent.ConfigTest do
  use ExUnit.Case
  doctest PowAssent.Config

  alias PowAssent.Config

  test "get/3" do
    Application.put_env(:pow_assent, :key, 1)
    assert Config.get([], :key) == 1

    Application.put_env(:test, :pow_assent, key: 2)
    assert Config.get([otp_app: :test], :key) == 2
  end

  test "get_providers/1" do
    Application.put_env(:pow_assent, :providers, [provider1: [], provider2: []])
    assert Config.get_providers([]) == [provider1: [], provider2: []]
  end

  test "get_provider_config/2" do
    Application.put_env(:pow_assent, :providers, [provider1: [a: 1], provider2: [b: 2]])
    assert Config.get_provider_config([], :provider2) == [b: 2]

    assert_raise PowAssent.Config.ConfigError, "No provider configuration available for non_existent.", fn ->
      Config.get_provider_config([], :non_existent)
    end

    assert Config.get_provider_config([http_adapter: HTTPAdapater, json_adapter: JSONAdapter, jwt_adapter: JWTAdapter], :provider1) ==
      [http_adapter: HTTPAdapater, json_adapter: JSONAdapter, jwt_adapter: JWTAdapter, a: 1]
  end

  test "get_provider_config/2 with binary provider" do
    config = [providers: [provider1: [a: 1], provider2: [b: 2]]]

    assert Config.get_provider_config(config, "provider1") == [a: 1]

    assert_raise PowAssent.Config.ConfigError, "No provider configuration available for non_existent.", fn ->
      refute Config.get_provider_config(config, "non_existent")
    end
  end
end
