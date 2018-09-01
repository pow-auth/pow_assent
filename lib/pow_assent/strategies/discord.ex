defmodule PowAssent.Strategy.Discord do
  @moduledoc """
  Discord OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              discord: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.Discord
              ]
            ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://discordapp.com/api",
      authorize_url: "/oauth2/authorize",
      token_url: "/oauth2/token",
      user_url: "/users/@me",
      authorization_params: [scope: "identify email"]
    ]
  end

  @spec normalize(Client.t(), Keyword.t(), map()) :: {:ok, map()}
  def normalize(_client, _config, user) do
    {:ok, %{
      "uid"        => user["id"],
      "name"       => user["username"],
      "email"      => verified_email(user),
      "image"      => "https://cdn.discordapp.com/avatars/#{user["id"]}/#{user["avatar"]}"}}
  end

  defp verified_email(%{"verified" => true} = user), do: user["email"]
  defp verified_email(_), do: nil
end
