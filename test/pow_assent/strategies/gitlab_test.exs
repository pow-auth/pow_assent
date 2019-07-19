defmodule PowAssent.Strategy.GitlabTest do
  use PowAssent.Test.OAuth2TestCase

  alias PowAssent.Strategy.Gitlab

  @user_response %{
    "id" => "1574083",
    "name" => "Snoop Dogg",
    "username" => "snoopdogg",
    "email" => "snoopdogg@example.com",
    "location" => "...",
    "avatar_url" => "...",
    "web_url" => "...",
    "website_url" => "..."
  }
  @user %{
    "uid" => "1574083",
    "name" => "Snoop Dogg",
    "nickname" => "snoopdogg",
    "email" => "snoopdogg@example.com",
    "location" => "...",
    "image" => "...",
    "urls" => %{
      "web_url" => "...",
      "website_url" => "..."
    }
  }

  test "authorize_url/2", %{config: config} do
    assert {:ok, %{url: url}} = Gitlab.authorize_url(config)
    assert url =~ "/oauth/authorize?client_id="
  end

  describe "callback/2" do
    test "normalizes data", %{config: config, callback_params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass, uri: "/oauth/token")
      expect_oauth2_user_request(bypass, @user_response, uri: "/api/v4/user")

      assert {:ok, %{user: user}} = Gitlab.callback(config, params)
      assert user == @user
    end

    test "handles error", %{config: config, callback_params: params, bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, %PowAssent.RequestError{error: :unreachable}} = Gitlab.callback(config, params)
    end
  end
end
