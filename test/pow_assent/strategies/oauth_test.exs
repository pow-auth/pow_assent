defmodule PowAssent.Strategy.OAuthTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.{RequestError, Strategy.OAuth}

  setup context do
    setup_bypass_oauth(context, user_url: "/api/user")
  end

  describe "authorize_url/2" do
    test "returns url", %{conn: conn, config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass)

      assert {:ok, %{conn: _conn, url: url}} = OAuth.authorize_url(config, conn)
      assert url =~ bypass_server(bypass) <> "/oauth/authenticate?oauth_token=token"
    end

    test "falls back to parse response as uri query", %{conn: conn, config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, content_type: "text/html", params: URI.encode_query(%{oauth_token: "token", oauth_token_secret: "token_secret"}))

      assert {:ok, _resp} = OAuth.authorize_url(config, conn)
    end

    test "bubbles up unexpected response", %{conn: conn, config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, params: %{"error_code" => 215, "error_message" => "Bad Authentication data."})

      assert {:error, %{conn: _conn, error: %RequestError{error: :unexpected_response}}} = OAuth.authorize_url(config, conn)
    end

    test "bubbles up error response", %{conn: conn, config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, status_code: 500, params: %{"error_code" => 215, "error_message" => "Bad Authentication data."})

      assert {:error, %{conn: _conn, error: %RequestError{error: :invalid_server_response}}} = OAuth.authorize_url(config, conn)
    end

    test "bubbles up json error response", %{conn: conn, config: config, bypass: bypass} do
      expect_oauth_request_token_request(bypass, status_code: 500, content_type: "application/json", params: %{"errors" => [%{"code" => 215, "message" => "Bad Authentication data."}]})

      assert {:error, %{conn: _conn, error: %RequestError{error: :invalid_server_response}}} = OAuth.authorize_url(config, conn)
    end

    test "bubbles up network error", %{conn: conn, config: config, bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %{conn: _conn, error: :econnrefused}} = OAuth.authorize_url(config, conn)
    end
  end

  describe "callback/2" do
    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth_access_token_request(bypass)
      expect_oauth_user_request(bypass, %{email: nil})

      expected = %{"email" => nil}

      {:ok, %{user: user}} = OAuth.callback(config, conn, params)
      assert expected == user
    end

    test "bubbles up error response", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth_access_token_request(bypass)
      expect_oauth_user_request(bypass, %{error: "Unknown error"}, status_code: 500)

      {:error, %{conn: _conn, error: %RequestError{error: :invalid_server_response}}} = OAuth.callback(config, conn, params)
    end
  end
end
