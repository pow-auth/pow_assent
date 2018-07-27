defmodule PowAssent.Strategy.Google do
  @moduledoc """
  Google OAuth 2.0 strategy.
  """
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.{Client, Strategy.AuthCode}

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), url: String.t(), state: String.t()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map(), client: Client.t()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config
    |> set_config()
    |> OAuth2Helper.callback(conn, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://www.googleapis.com/plus/v1",
      authorize_url: "https://accounts.google.com/o/oauth2/auth",
      token_url: "https://accounts.google.com/o/oauth2/token",
      user_url: "/people/me/openIdConnect",
      authorization_params: [scope: "email profile"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp normalize({:ok, %{conn: conn, user: user, client: client}}) do
    user = %{
      "uid"        => user["sub"],
      "name"       => user["name"],
      "email"      => verified_email(user),
      "first_name" => user["given_name"],
      "last_name"  => user["family_name"],
      "image"      => user["picture"],
      "domain"     => user["hd"],
      "urls"       => %{
        "Google" => user["profile"]}}

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}

  defp verified_email(%{"email_verified" => "true"} = user), do: user["email"]
  defp verified_email(_), do: nil
end
