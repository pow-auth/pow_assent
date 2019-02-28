defmodule PowAssent.Strategy.Google do
  @moduledoc """
  Google OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          google: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.Google
          ]
        ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://www.googleapis.com",
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "/oauth2/v4/token",
      user_url: "/oauth2/v2/userinfo",
      authorization_params: [scope: "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"        => user["id"],
      "name"       => user["name"],
      "email"      => verified_email(user),
      "first_name" => user["given_name"],
      "last_name"  => user["family_name"],
      "image"      => user["picture"],
      "domain"     => user["hd"],
      "urls"       => %{"Google" => user["link"]}}}
  end

  defp verified_email(%{"verified_email" => true} = user), do: user["email"]
  defp verified_email(_), do: nil
end
