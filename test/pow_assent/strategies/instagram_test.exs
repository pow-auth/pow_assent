defmodule PowAssent.Strategy.InstagramTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.Instagram

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass)]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Instagram.authorize_url(config, conn)
    assert url =~ "/oauth/authorize?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        user = %{
          "id" => "1574083",
          "username" => "snoopdogg",
          "full_name" => "Snoop Dogg",
          "profile_picture" => "..."
        }

        send_resp(conn, 200, Poison.encode!(%{access_token: @access_token, user: user}))
      end)

      expected = %{
        "image" => "...",
        "name" => "Snoop Dogg",
        "nickname" => "snoopdogg",
        "uid" => "1574083"
      }

      {:ok, %{user: user}} = Instagram.callback(config, conn, params)
      assert expected == user
    end
  end
end
