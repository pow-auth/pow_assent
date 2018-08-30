defmodule PowAssent.Strategy.GoogleTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.Google

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass), token_url: "/o/oauth2/token"]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Google.authorize_url(config, conn)
    assert url =~ "https://accounts.google.com/o/oauth2/auth?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/o/oauth2/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/people/me/openIdConnect", fn conn ->
        assert_access_token_in_header(conn, @access_token)

        user = %{
          "kind" => "plus#personOpenIdConnect",
          "gender" => "",
          "sub" => "1",
          "name" => "Dan Schultzer",
          "given_name" => "Dan",
          "family_name" => "Schultzer",
          "profile" => "https://example.com/profile",
          "picture" => "https://example.com/images/profile.jpg",
          "email" => "foo@example.com",
          "email_verified" => "true",
          "locale" => "en-US",
          "hd" => "example.com"
        }

        Plug.Conn.resp(conn, 200, Poison.encode!(user))
      end)

      expected = %{
        "email" => "foo@example.com",
        "image" => "https://example.com/images/profile.jpg",
        "name" => "Dan Schultzer",
        "first_name" => "Dan",
        "last_name" => "Schultzer",
        "domain" => "example.com",
        "uid" => "1",
        "urls" => %{"Google" => "https://example.com/profile"}
      }

      {:ok, %{user: user}} = Google.callback(config, conn, params)
      assert expected == user
    end
  end
end
