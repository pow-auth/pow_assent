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

  test "authorize_url/2", %{config: config} do
    assert {:ok, %{url: url}} = Auth0.authorize_url(config)
    assert url =~ "/authorize"
  end

  test "callback/2", %{config: config, callback_params: params, bypass: bypass} do
    expect_oauth2_access_token_request(bypass, uri: "/oauth/token")
    expect_oauth2_user_request(bypass, @user_response, uri: "/userinfo")

    assert {:ok, %{user: user}} = Auth0.callback(config, params)
    assert user == @user
  end
end
