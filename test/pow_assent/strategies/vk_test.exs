defmodule PowAssent.VKTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.VK

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open
    config = [site: bypass_server(bypass),
              authorize_url: "/authorize",
              token_url: "/access_token"]

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
      Bypass.expect_once bypass, "POST", "/access_token", fn conn ->
        assert {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert body =~ "scope=email"

        send_resp(conn, 200, Poison.encode!(%{"access_token" => @access_token, "email" => "lindsay.stirling@example.com"}))
      end

      Bypass.expect_once bypass, "GET", "/method/users.get", fn conn ->
        assert_access_token_in_header conn, @access_token

        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.params["fields"] == "uid,first_name,last_name,photo_200,screen_name,verified"
        assert conn.params["v"] == "5.69"
        assert conn.params["access_token"] == @access_token

        users = [%{"id" => 210700286,
                   "first_name" => "Lindsay",
                   "last_name" => "Stirling",
                   "screen_name" => "lindseystirling",
                   "photo_200" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
                   "verified" => 1}]

        Plug.Conn.resp(conn, 200, Poison.encode!(%{"response" => users}))
      end

      expected = %{"email" => "lindsay.stirling@example.com",
                   "first_name" => "Lindsay",
                   "last_name" => "Stirling",
                   "name" => "Lindsay Stirling",
                   "nickname" => "lindseystirling",
                   "uid" => "210700286",
                   "image" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
                   "verified" => true}

      {:ok, %{user: user}} = VK.callback(config, conn, params)
      assert expected == user
    end
  end
end
