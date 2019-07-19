defmodule PowAssent.Strategy.Gitlab do
  @moduledoc """
  Gitlab OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          gitlab: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.Gitlab
          ]
        ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://gitlab.com",
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token",
      user_url: "/api/v4/user",
      authorization_params: [scope: "api read_user read_registry"]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"        => user["id"],
      "name"       => user["name"],
      "nickname"   => user["username"],
      "email"      => user["email"],
      "location"   => user["location"],
      "image"      => user["avatar_url"],
      "urls"       => %{
        "web_url"     => user["web_url"],
        "website_url" => user["website_url"]
      }
    }}
  end
end
