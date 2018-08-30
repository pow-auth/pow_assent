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
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.{Client, Strategy.AuthCode}

  @api_version "2.12"

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config = set_config(config)
    client = Client.new(config)
    state  = conn.private[:pow_assent_state]

    state
    |> OAuth2Helper.check_state(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> get_user(config)
    |> normalize(client)
    |> case do
      {:ok, user}     -> {:ok, %{conn: conn, user: user, client: client}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end

  defp set_config(config) do
    [
      site: "https://graph.facebook.com/v#{@api_version}",
      authorize_url: "https://www.facebook.com/v#{@api_version}/dialog/oauth",
      token_url: "/oauth/access_token",
      user_url: "/me",
      authorization_params: [scope: "email"],
      user_url_request_fields: "name,email"
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp get_user({:ok, client}, config) do
    params = %{
      "appsecret_proof" => appsecret_proof(client),
      "fields" => config[:user_url_request_fields]}
    user_url = config[:user_url] <> "?" <> URI.encode_query(params)

    OAuth2Helper.get_user({:ok, client}, user_url)
  end
  defp get_user({:error, error}, _config), do: {:error, error}

  defp normalize({:ok, user}, client) do
    user = %{
      "uid"         => user["id"],
      "nickname"    => user["username"],
      "email"       => user["email"],
      "name"        => user["name"],
      "first_name"  => user["first_name"],
      "last_name"   => user["last_name"],
      "location"    => (user["location"] || %{})["name"],
      "image"       => image_url(client, user),
      "description" => user["bio"],
      "urls"        => %{
        "Facebook" => user["link"],
        "Website"  => user["website"]},
      "verified"    => user["verified"]}

    {:ok, Helpers.prune(user)}
  end
  defp normalize({:error, error}, _client), do: {:error, error}

  defp image_url(client, user) do
    "#{client.site}/#{user["id"]}/picture"
  end

  defp appsecret_proof(client) do
    :sha256
    |> :crypto.hmac(client.client_secret, client.token.access_token)
    |> Base.encode16(case: :lower)
  end
end
