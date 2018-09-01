defmodule PowAssent.Strategy.Google do
  @moduledoc """
  Google OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
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
      site: "https://www.googleapis.com/plus/v1",
      authorize_url: "https://accounts.google.com/o/oauth2/auth",
      token_url: "https://accounts.google.com/o/oauth2/token",
      user_url: "/people/me/openIdConnect",
      authorization_params: [scope: "email profile"]
    ]
  end

  @spec normalize(Client.t(), Keyword.t(), map()) :: {:ok, map()}
  def normalize(_client, _config, user) do
    {:ok, %{
      "uid"        => user["sub"],
      "name"       => user["name"],
      "email"      => verified_email(user),
      "first_name" => user["given_name"],
      "last_name"  => user["family_name"],
      "image"      => user["picture"],
      "domain"     => user["hd"],
      "urls"       => %{
        "Google" => user["profile"]}}}
  end

  defp verified_email(%{"email_verified" => "true"} = user), do: user["email"]
  defp verified_email(_), do: nil
end
