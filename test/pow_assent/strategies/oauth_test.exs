defmodule PowAssent.Strategy.OAuthTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.OAuth

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass), user_url: "/api/user"]
    params = %{"oauth_token" => "test", "oauth_verifier" => "test"}

    {:ok, conn: conn, config: config, params: params, bypass: bypass}
  end

  describe "authorize_url/2" do
    test "returns url", %{conn: conn, config: config, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/request_token", fn conn ->
        token = %{
          oauth_token: "token",
          oauth_token_secret: "token_secret"
        }

        conn
        |> put_resp_content_type("text/plain")
        |> Plug.Conn.resp(200, URI.encode_query(token))
      end)

      assert {:ok, %{conn: _conn, url: url}} = OAuth.authorize_url(config, conn)
      assert url =~ bypass_server(bypass) <> "/oauth/authenticate?oauth_token=token"
    end

    test "bubbles up network error", %{conn: conn, config: config, bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %{conn: _conn, error: :econnrefused}} = OAuth.authorize_url(config, conn)
    end
  end

  describe "callback/2" do
    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/access_token", fn conn ->
        token = %{
          oauth_token: "7588892-kagSNqWge8gB1WwE3plnFsJHAZVfxWD7Vb57p0b4&",
          oauth_token_secret: "PbKfYqSryyeKDWz4ebtY3o5ogNLG11WJuZBc9fQrQo"
        }

        conn
        |> put_resp_content_type("text/plain")
        |> Plug.Conn.resp(200, URI.encode_query(token))
      end)

      Bypass.expect_once(bypass, "GET", "/api/user", fn conn ->
        user = %{email: nil}

        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(user))
      end)

      expected = %{"email" => nil}

      {:ok, %{user: user}} = OAuth.callback(config, conn, params)
      assert expected == user
    end

    test "bubbles up network error", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/access_token", fn conn ->
        token = %{
          oauth_token: "7588892-kagSNqWge8gB1WwE3plnFsJHAZVfxWD7Vb57p0b4&",
          oauth_token_secret: "PbKfYqSryyeKDWz4ebtY3o5ogNLG11WJuZBc9fQrQo"
        }

        conn
        |> put_resp_content_type("text/plain")
        |> Plug.Conn.resp(200, URI.encode_query(token))
      end)

      Bypass.expect_once(bypass, "GET", "/api/user", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{error: "Unknown error"}))
      end)

      {:error, %{conn: _conn, error: %{status: 500, body: %{"error" => "Unknown error"}}}} = OAuth.callback(config, conn, params)
    end
  end
end
