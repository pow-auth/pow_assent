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

  test "merge_provider_config/2" do
    Application.put_env(:pow_assent, :providers, [
      provider1: [
        a: 1,
        b: 2,
        authorization_params: [c: 3, d: 4],
        strategy: PowAssent.Test.TestProvider
      ]
    ])

    new_config = [
      a: 2,
      c: 3,
      authorization_params: [c: 4, e: 5]
    ]

    expected_config = [
      providers: [
        provider1: [
          b: 2,
          strategy: PowAssent.Test.TestProvider,
          a: 2,
          c: 3,
          authorization_params: [scope: "user:read user:write", d: 4, c: 4, e: 5]
        ]
      ]
    ]

    assert Config.merge_provider_config([], :provider1, new_config) == expected_config
  end

  test "get_provider_config/2" do
    Application.put_env(:pow_assent, :providers, [provider1: [a: 1], provider2: [b: 2]])
    assert Config.get_provider_config([], :provider2) == [b: 2]

    assert_raise PowAssent.Config.ConfigError, "No provider configuration available for non_existent.", fn ->
      Config.get_provider_config([], :non_existent)
    end

    assert Config.get_provider_config([http_adapter: HTTPAdapter, json_adapter: JSONAdapter, jwt_adapter: JWTAdapter], :provider1) ==
      [http_adapter: HTTPAdapter, json_adapter: JSONAdapter, jwt_adapter: JWTAdapter, a: 1]
  end
end
