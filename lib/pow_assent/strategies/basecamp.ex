defmodule PowAssent.Strategy.Basecamp do
  @moduledoc """
  Basecamp OAuth 2.0 strategy.
  """
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.{Client, Strategy.AuthCode}

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config = set_config(config)

    config
    |> OAuth2Helper.callback(conn, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://launchpad.37signals.com",
      authorize_url: "/authorization/new",
      token_url: "/authorization/token",
      user_url: "/authorization.json",
      authorization_params: [type: "web_server"],
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp normalize({:ok, %{conn: conn, user: user, client: client}}) do
    user = %{
      "uid"         => Integer.to_string(user["identity"]["id"]),
      "name"        => "#{user["identity"]["first_name"]} #{user["identity"]["last_name"]}",
      "first_name"  => user["identity"]["first_name"],
      "last_name"   => user["identity"]["last_name"],
      "email"       => user["identity"]["email_address"],
      "accounts"    => user["accounts"]}

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
