defmodule PowAssent.Strategy.OAuthTest do
  use PowAssent.Test.OAuthTestCase

  alias PowAssent.{RequestError, Strategy.OAuth}

  describe "authorize_url/2" do
    test "returns url", %{config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass)

      assert {:ok, %{url: url}} = OAuth.authorize_url(config)
      assert url =~ "http://localhost:#{bypass.port}/oauth/authenticate?oauth_token=token"
    end

    test "parses URI query response", %{config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, content_type: "text/html", params: URI.encode_query(%{oauth_token: "token", oauth_token_secret: "token_secret"}))

      assert {:ok, %{url: url}} = OAuth.authorize_url(config)
      assert url =~ "http://localhost:#{bypass.port}/oauth/authenticate?oauth_token=token"
    end

    test "bubbles up unexpected response with HTTP status 200", %{config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, params: %{"error_code" => 215, "error_message" => "Bad Authentication data."})

      assert {:error, %RequestError{error: :unexpected_response}} =OAuth.authorize_url(config)
    end

    test "bubbles up error response", %{config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, status_code: 500, params: %{"error_code" => 215, "error_message" => "Bad Authentication data."})

      assert {:error, %RequestError{error: :invalid_server_response}} = OAuth.authorize_url(config)
    end

    test "bubbles up json error response", %{config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, status_code: 500, content_type: "application/json", params: %{"errors" => [%{"code" => 215, "message" => "Bad Authentication data."}]})

      assert {:error, %RequestError{error: :invalid_server_response}} = OAuth.authorize_url(config)
    end

    test "bubbles up network error", %{config: config, bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %PowAssent.RequestError{error: :unreachable}} = OAuth.authorize_url(config)
    end
  end

  describe "callback/2" do
    setup %{config: config} = context do
      config = Keyword.put(config, :user_url, "/api/user")

      %{context | config: config}
    end

    test "normalizes data", %{config: config, callback_params: params, bypass: bypass} do
      expect_oauth_access_token_request(bypass)
      expect_oauth_user_request(bypass, %{email: nil})

      assert {:ok, %{user: %{"email" => nil}}} = OAuth.callback(config, params)
    end

    test "bubbles up error response", %{config: config, callback_params: params, bypass: bypass} do
      expect_oauth_access_token_request(bypass)
      expect_oauth_user_request(bypass, %{error: "Unknown error"}, status_code: 500)

      assert {:error, %RequestError{error: :invalid_server_response}} = OAuth.callback(config, params)
    end
  end
end
