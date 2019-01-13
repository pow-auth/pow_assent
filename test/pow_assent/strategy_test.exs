defmodule PowAssent.StrategyTest do
  use ExUnit.Case
  doctest PowAssent.Strategy

  alias PowAssent.Strategy

  test "prune/1" do
    map      = %{a: :ok, b: nil, c: "", d: %{a: :ok, b: nil}}
    expected = %{a: :ok, c: "", d: %{a: :ok}}

    assert Strategy.prune(map) == expected
  end

  test "decode_response/1" do
    expected = %{"a" => "1", "b" => "2"}

    headers = [{"content-type", "application/json"}]
    body = Jason.encode!(expected)
    assert Strategy.decode_response({nil, %{body: body, headers: headers}}, []) == {nil, %{body: expected, headers: headers}}

    headers = [{"content-type", "application/json; charset=utf-8"}]
    assert Strategy.decode_response({nil, %{body: body, headers: headers}}, []) == {nil, %{body: expected, headers: headers}}

    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    body = URI.encode_query(expected)
    assert Strategy.decode_response({nil, %{body: body, headers: headers}}, []) == {nil, %{body: expected, headers: headers}}

    headers = [{"content-type", "application/x-www-form-urlencoded; charset=utf-8"}]
    assert Strategy.decode_response({nil, %{body: body, headers: headers}}, []) == {nil, %{body: expected, headers: headers}}
  end
end
