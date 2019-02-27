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
end
