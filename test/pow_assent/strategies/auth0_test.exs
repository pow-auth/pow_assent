defmodule PowAssent.Strategy.Auth0Test do
  use PowAssent.Test.OAuth2TestCase

  alias PowAssent.Strategy.Auth0

  @user_response %{
    "sub" => 9_999_999,
    "given_name" => "Jason",
    "family_name" => "Fried",
    "name" => "Jason Fried",
    "preferred_username" => "jfried",
    "email" => "jason@auth0.com",
    "picture" => "...",
    "email_verified" => true
  }
  @user %{
    "uid" => 9_999_999,
    "nickname" => "jfried",
    "email" => "jason@auth0.com",
    "first_name" => "Jason",
    "last_name" => "Fried",
    "name" => "Jason Fried",
    "image" => "...",
    "verified" => true
  }

  describe "authorize_url/2" do
    test "requires domain or site configuration" do
      assert_raise PowAssent.Config.ConfigError, "`:domain` or `:site` configuration setting is required for PowAssent.Strategy.Auth0 strategy", fn ->
        Auth0.authorize_url([])
      end

      assert {:ok, %{url: url}} = Auth0.authorize_url([site: "https://localhost"])
      assert url =~ "https://localhost/authorize"

      assert {:ok, %{url: url}} = Auth0.authorize_url([domain: "demo.auth0.com"])
      assert url =~ "https://demo.auth0.com/authorize"

      assert {:ok, %{url: url}} = Auth0.authorize_url([domain: "http://demo.auth0.com"])
      assert url =~ "http://demo.auth0.com/authorize"
    end
  end

  test "callback/2", %{config: config, callback_params: params, bypass: bypass} do
    expect_oauth2_access_token_request(bypass, uri: "/oauth/token")
    expect_oauth2_user_request(bypass, @user_response, uri: "/userinfo")

    assert {:ok, %{user: user}} = Auth0.callback(config, params)
    assert user == @user
  end
end
