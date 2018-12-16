defmodule PowAssent.Strategy.DiscordTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.Discord

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass)]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Discord.authorize_url(config, conn)
    assert url =~ "/oauth2/authorize?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth2/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{access_token: @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/users/@me", fn conn ->
        assert_access_token_in_header(conn, @access_token)

        user = %{
          "id" => "80351110224678912",
          "username" => "Nelly",
          "discriminator" => "1337",
          "avatar" => "8342729096ea3675442027381ff50dfe",
          "verified" => true,
          "email" => "nelly@discordapp.com"
        }

        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(user))
      end)

      expected = %{
        "email" => "nelly@discordapp.com",
        "name" => "Nelly",
        "uid" => "80351110224678912",
        "image" => "https://cdn.discordapp.com/avatars/80351110224678912/8342729096ea3675442027381ff50dfe"
      }

      {:ok, %{user: user}} = Discord.callback(config, conn, params)
      assert expected == user
    end
  end
end
