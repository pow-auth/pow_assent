defmodule PowAssent.Strategy.InstagramTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.Instagram

  @user_response %{
    "id" => "1574083",
    "username" => "snoopdogg",
    "full_name" => "Snoop Dogg",
    "profile_picture" => "..."
  }

  setup :setup_bypass

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
      expect_oauth2_access_token_request(bypass, uri: "/oauth/token", params: %{access_token: "access_token", user: @user_response})

      expected = %{
        "image" => "...",
        "name" => "Snoop Dogg",
        "nickname" => "snoopdogg",
        "uid" => "1574083"
      }

      {:ok, %{user: user}} = Instagram.callback(config, conn, params)
      assert expected == user
    end

    test "handles error", %{config: config, conn: conn, params: params} do
      config = Keyword.put(config, :site, "http://localhost:8888")

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = Instagram.callback(config, conn, params)
      assert error == :econnrefused
    end
  end
end
