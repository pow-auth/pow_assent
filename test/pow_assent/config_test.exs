defmodule PowAssent.ConfigTest do
  use ExUnit.Case
  doctest PowAssent.Config

  alias PowAssent.Config

  setup do
    Application.delete_env(:pow_assent, :key)
    Application.delete_env(:test, :pow_assent)
  end

  test "env_config/1" do
    refute Config.env_config([])[:key]
    refute Config.env_config([otp_app: :test])

    Application.put_env(:pow_assent, :key, 1)
    assert Config.env_config([])[:key] == 1

    Application.put_env(:test, :pow_assent, [key: 2])
    assert Config.env_config([otp_app: :test]) == [key: 2]
  end
end
