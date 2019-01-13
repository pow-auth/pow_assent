defmodule PowAssent.Strategy.DiscordTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.Discord

  @user_response %{
    "id" => "80351110224678912",
    "username" => "Nelly",
    "discriminator" => "1337",
    "avatar" => "8342729096ea3675442027381ff50dfe",
    "verified" => true,
    "email" => "nelly@discordapp.com"
  }

  setup :setup_bypass

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
      expect_oauth2_access_token_request(bypass, uri: "/oauth2/token")
      expect_oauth2_user_request(bypass, @user_response, uri: "/users/@me")

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
