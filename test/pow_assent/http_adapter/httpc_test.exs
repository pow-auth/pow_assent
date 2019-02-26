defmodule PowAssent.HTTPAdapter.HttpcTest do
  use ExUnit.Case
  doctest PowAssent.HTTPAdapter.Httpc

  alias PowAssent.HTTPAdapter.{Httpc, HTTPResponse}

  @expired_certificate_url "https://expired.badssl.com"
  @hsts_certificate_url "https://hsts.badssl.com"

  describe "request/4" do
    test "handles SSL" do
      assert {:ok, %HTTPResponse{status: 200}} = Httpc.request(:get, @hsts_certificate_url, nil, [])
      assert {:error, :econnrefused} = Httpc.request(:get, @expired_certificate_url, nil, [])

      assert {:ok, %HTTPResponse{status: 200}} = Httpc.request(:get, @expired_certificate_url, nil, [], [])
    end
  end
end
