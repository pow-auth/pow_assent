defmodule PowAssent.Strategy.Facebook do
  @moduledoc """
  Facebook OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
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
      user_url_request_fields: "name,email",
      get_user_fn: &get_user/2
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

  @spec get_user(Keyword.t(), Client.t()) :: {:ok, map()} | {:error, any()}
  def get_user(config, client) do
    params = %{
      "appsecret_proof" => appsecret_proof(client),
      "fields" => config[:user_url_request_fields]}
    config = Keyword.put(config, :user_url, user_url(config, params))

    OAuth2.get_user(config, client)
  end

  defp appsecret_proof(client) do
    :sha256
    |> :crypto.hmac(client.client_secret, client.token.access_token)
    |> Base.encode16(case: :lower)
  end

  defp user_url(config, params), do: config[:user_url] <> "?" <> URI.encode_query(params)
end
