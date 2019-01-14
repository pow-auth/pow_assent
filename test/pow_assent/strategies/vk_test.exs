defmodule PowAssent.Strategy.VKTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.VK

  @users_response [
    %{
      "id" => 210_700_286,
      "first_name" => "Lindsay",
      "last_name" => "Stirling",
      "screen_name" => "lindseystirling",
      "photo_200" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
      "verified" => 1
    }
  ]

  setup %{conn: conn} do
    bypass = Bypass.open()

    config = [
      site: bypass_server(bypass),
      authorize_url: "/authorize",
      token_url: "/access_token"
    ]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = VK.authorize_url(config, conn)
    assert url =~ "/authorize"
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test", "state" => "test"}
      conn = Plug.Conn.put_private(conn, :pow_assent_state, "test")

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass, [uri: "/access_token", params: %{"access_token" => "access_token", "email" => "lindsay.stirling@example.com"}], fn conn ->
        assert conn.query_string =~ "scope=email"
      end)

      expect_oauth2_user_request(bypass, %{"response" => @users_response}, [uri: "/method/users.get"], fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.params["access_token"] == "access_token"
        assert conn.params["fields"] == "uid,first_name,last_name,photo_200,screen_name,verified"
        assert conn.params["v"] == "5.69"
        assert conn.params["access_token"] == "access_token"
      end)

      expected = %{
        "email" => "lindsay.stirling@example.com",
        "first_name" => "Lindsay",
        "last_name" => "Stirling",
        "name" => "Lindsay Stirling",
        "nickname" => "lindseystirling",
        "uid" => "210700286",
        "image" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
        "verified" => true
      }

      {:ok, %{user: user}} = VK.callback(config, conn, params)
      assert expected == user
    end

    test "handles error", %{config: config, conn: conn, params: params} do
      config = Keyword.put(config, :site, "http://localhost:8888")

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = VK.callback(config, conn, params)
      assert error == :econnrefused
    end
  end
end
