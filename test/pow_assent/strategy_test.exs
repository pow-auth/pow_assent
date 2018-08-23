defmodule PowAssent.StrategyTest do
  use ExUnit.Case
  doctest PowAssent.Strategy

  alias PowAssent.Strategy

  test "prune/1" do
    map      = %{a: :ok, b: nil, c: "", d: %{a: :ok, b: nil}}
    expected = %{a: :ok, c: "", d: %{a: :ok}}

    assert Strategy.prune(map) == expected
  end
end
