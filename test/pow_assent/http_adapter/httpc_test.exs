defmodule PowAssent.HTTPAdapter.HttpcTest do
  use ExUnit.Case
  doctest PowAssent.HTTPAdapter.Httpc

  alias PowAssent.HTTPAdapter.{Httpc, HTTPResponse}

  @expired_certificate_url "https://expired.badssl.com"
  @hsts_certificate_url "https://hsts.badssl.com"
  @unreachable_http_url "http://localhost:8888/"
  @expired_certificate_error [
    {:to_address, {'expired.badssl.com', 443}},
    {:inet, [:inet], {:tls_alert, 'certificate expired'}}
  ]
  @unreachable_http_error [
    {:to_address, {'localhost', 8888}},
    {:inet, [:inet], :econnrefused}
  ]

  describe "request/4" do
    test "handles SSL" do
      assert {:ok, %HTTPResponse{status: 200}} = Httpc.request(:get, @hsts_certificate_url, nil, [])
      assert {:error, {:failed_connect, @expired_certificate_error}} = Httpc.request(:get, @expired_certificate_url, nil, [])

      assert {:ok, %HTTPResponse{status: 200}} = Httpc.request(:get, @expired_certificate_url, nil, [], ssl: [])

      assert {:error, {:failed_connect, @unreachable_http_error}} = Httpc.request(:get, @unreachable_http_url, nil, [])
    end
  end
end
