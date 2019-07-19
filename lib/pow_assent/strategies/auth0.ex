defmodule PowAssent.Strategy.Auth0 do
  @moduledoc """
  Auth0 OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          auth0: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.Auth0
          ]
        ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(config) do
    domain = Keyword.get(config, :domain)

    [
      site: "https://#{domain}",
      authorize_url: "/authorize",
      token_url: "/oauth/token",
      user_url: "/userinfo",
      authorization_params: [scope: "openid profile email"]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()} | {:error, term()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"        => user["sub"],
      "nickname"   => user["preferred_username"],
      "email"      => user["email"],
      "first_name" => user["given_name"],
      "last_name"  => user["family_name"],
      "name"       => user["name"],
      "image"      => user["picture"],
      "verified"   => user["email_verified"]
    }}
  end
end
