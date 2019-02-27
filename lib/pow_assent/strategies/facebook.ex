defmodule PowAssent.Strategy.Facebook do
  @moduledoc """
  Facebook OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          facebook: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.Facebook
          ]
        ]
  """
  use PowAssent.Strategy.OAuth2.Base

  alias PowAssent.Strategy.OAuth2

  @api_version "2.12"

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://graph.facebook.com/v#{@api_version}",
      authorize_url: "https://www.facebook.com/v#{@api_version}/dialog/oauth",
      token_url: "/oauth/access_token",
      user_url: "/me",
      authorization_params: [scope: "email"],
      user_url_request_fields: "name,email"
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(config, user) do
    {:ok, %{
      "uid"         => user["id"],
      "nickname"    => user["username"],
      "email"       => user["email"],
      "name"        => user["name"],
      "first_name"  => user["first_name"],
      "last_name"   => user["last_name"],
      "location"    => (user["location"] || %{})["name"],
      "image"       => image_url(config, user),
      "description" => user["bio"],
      "urls"        => %{
        "Facebook" => user["link"],
        "Website"  => user["website"]},
      "verified"    => user["verified"]
    }}
  end

  defp image_url(config, user) do
    "#{config[:site]}/#{user["id"]}/picture"
  end

  @spec get_user(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
  def get_user(config, access_token) do
    params = %{
      "appsecret_proof" => appsecret_proof(config, access_token),
      "fields" => config[:user_url_request_fields],
      "access_token" => access_token["access_token"]
    }

    OAuth2.get_user(config, access_token, params)
  end

  defp appsecret_proof(config, access_token) do
    client_secret = Keyword.get(config, :client_secret)

    :sha256
    |> :crypto.hmac(client_secret, access_token["access_token"])
    |> Base.encode16(case: :lower)
  end
end
